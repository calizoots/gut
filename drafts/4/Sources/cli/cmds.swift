import Foundation
import AppKit

@MainActor
func BackupEditCmd(args: [String], slf: Command) async -> Void {
    if args.count < 2 {
        log.print(.error, """
            missing required arguments.

            Usage:
              vols backup edit <name> <name of usb>

            Example:
              vols backup edit test str8corn
            """, ignoreverbose: true)
        return
    }

    let key: String

    do {
        key = try db.getSerial()
    } catch {
        log.print(.error, "some error from getSerial(): \(error)")
        return
    }

    let usbcopy = USB()

    for (i, vol) in usbcopy.usbDevices.enumerated() {
        if vol.serial == key {
            usbcopy.usbDevices.remove(at: i)
            break
        }
    }

    let name = args[0]
    let usbname = args[1]
    var volume: Volume?
    var device: USBDevice?

    for vol in volmngr.vols {
        if name == vol.name {
            volume = vol
        }
    }

    for dev in usbcopy.usbDevices {
        if dev.name == usbname {
            device = dev
        }
    }

    if volume == nil {
        log.print(.info, "available vols:")
        for vol in volmngr.vols {
            vol.print(log) 
            log.print(.info, String(repeating: "-----------", count: 5))
        }
        log.print(.error, "volume \(name) was not found")
        return
    } else if device == nil {
        log.print(.info, "available usb devices:")
        for dev in usbcopy.usbDevices {
            dev.print(log) 
            log.print(.info, String(repeating: "-----------", count: 5))
        }
        log.print(.error, "usb device \(usbname) was not found excluding your key")
        return
    }

    if let dev = device, let vol = volume {
        do {
            try db.setBackupPath(of: vol, to: dev.volumepath.path)
            log.print(.info, "set backup path to \(dev.volumepath.path)")
        } catch {
            log.print(.error, "db setBackupPath() failed: \(error)")
        }
    }
}

@MainActor
func BackupDoCmd(args: [String], slf: Command) -> Void {
    if let volume = CheckArgsVolsSubCmd("backup do", args: args) {
        if let backupPath = volume.backuppath {
            let _ = CheckIfFolderExists(backupPath) { _, _  in
                log.print(.error, "your backup device isn't inserted or mounted")
                exit(69)
            }

            var backupP = URL(filePath: backupPath).appendingPathComponent(".utility", conformingTo: .folder)

            let _ = CheckIfFolderExists(backupP.path) { _, _  in
                do {
                    try FileManager.default.createDirectory(at: backupP, withIntermediateDirectories: false)
                } catch {
                    log.print(.error, "failed to make backup container folder: \(backupP.path), error: \(error)")
                    return
                }
            }
            
            let bundlePath = URL(filePath: volume.path)
            backupP = backupP.appendingPathComponent(bundlePath.lastPathComponent, conformingTo: .folder)

            let _ = CheckIfFolderExists(backupP.path) { _, _  in
                do {
                    try FileManager.default.createDirectory(at: backupP, withIntermediateDirectories: false)
                } catch {
                    log.print(.error, "failed to make backup container folder: \(backupP.path), error: \(error)")
                    return
                }
            }

            do {
                log.print(.info, "starting rsync this might take a while...")
                try RunRsync(from: volume.path, to: backupP.path) 
            } catch {
                log.print(.error, "failed to run rsync: \(error)")
            }
        } else {
            log.print(.error, "no backup path is set.")
        }
    }
}

@MainActor
func BackupCmd(args: [String], slf: Command) async -> Void {
    slf.registerSubCommand("edit", description: "edit the backup path of a volume", callback: BackupEditCmd)

    slf.registerSubCommand("do", description: "do a backup to the backup path", callback: BackupDoCmd)

    await slf.RunSubCommand(args: args)
}

@MainActor
func CreateCmd(args: [String], slf: Command) -> Void {
    var name: String?
    var mountPoint: String?
    var size: Int?

    var i = 0
    while i < args.count {
        switch args[i] {
        case "-name":
            if i + 1 < args.count {
                name = args[i + 1]
                i += 1
            }
        case "-mountpoint":
            if i + 1 < args.count {
                mountPoint = args[i + 1]
                i += 1
            }
        case "-sizeM":
            if i + 1 < args.count, let s = Int(args[i + 1]) {
                size = s
                i += 1
            }
        case "-sizeG":
            if i + 1 < args.count, let s = Int(args[i + 1]) {
                size = s * 1024
                i += 1
            }
        default:
            break
        }
        i += 1
    }

    if name == nil || mountPoint == nil || size == nil {
        log.print(.error, """
            missing required arguments.

            Usage:
              vols create -name <NAME> -mountpoint <PATH> -sizeM <SIZE_MB> -sizeG <SIZE_MB>

            Example:
              vols create -name secure -mountpoint /Volumes/secure -sizeM 500
            """, ignoreverbose: true)
        return
    }

    
    var isDir: ObjCBool = true
    if !FileManager.default.fileExists(atPath: mountPoint!, isDirectory: &isDir), isDir.boolValue {
        log.print(.error, "mount point you entered doesn't exist")
        return
    }

    do {
        _ = try volmngr.makeVol(at: datadir.appending(path: "\(name!).sparsebundle").path, mountPoint: mountPoint!, volumeName: name!, sizeMB: size!)
        log.print(.info, "created volume '\(name!)' at \(mountPoint!) with size \(size!) MB")
    } catch {
        log.print(.error, "failed to make volume: \(error)")
    }
}

@MainActor
func MountCmd(args: [String], slf: Command) async -> Void {
    if let volume = CheckArgsVolsSubCmd("mount", args: args) {
        do {
            _ = try volmngr.getPassword()
        } catch {
            await showInsertKey(vol: volume, usb: usb, volmngr: volmngr)

                log.print(.info, "mounted volume \(volume.name) at \(volume.mountpath)")
                return
        }

        do {
            _ = try volume.mount(password: try volmngr.getPassword())
                log.print(.info, "mounted volume \(volume.name) at \(volume.mountpath)")
        } catch {
            log.print(.error, "failed to mount volume \(error)")
        }
    }
}

@MainActor
func EjectCmd(args: [String], slf: Command) -> Void {
    if let volume = CheckArgsVolsSubCmd("eject", args: args) {
        do {
            try volume.eject()
                log.print(.info, "ejected volume \(volume.name)")
        } catch {
            log.print(.error, "failed to eject volume \(error)")
        }
    }
}
