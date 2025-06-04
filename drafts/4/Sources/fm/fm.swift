import Foundation

class Volume {
    let id: Int?
    let name: String
    let size: Int64
    let path: String
    let backuppath: String?
    let mountpath: String
    let keySerial: String

    func print(_ log: Logger) {
        log.print(.info, "Name: \(name)")
        log.print(.info, "Size (MB): \(size)")
        log.print(.info, "Sparsebundle path: \(path)")
        log.print(.info, "Mount point: \(mountpath)")
    }

    @MainActor
    func mount(password: String) throws -> URL? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
        process.arguments = [
            "attach",
            path,
            "-stdinpass",
            // "-nobrowse", // optional: hides in Finder
            "-mountpoint", mountpath,
            "-quiet"
        ]
    
        let inputPipe = Pipe()
        process.standardInput = inputPipe
        process.standardOutput = Pipe()
        process.standardError = Pipe()

        try process.run()
    
        inputPipe.fileHandleForWriting.write((password).data(using: .utf8)!)
        inputPipe.fileHandleForWriting.closeFile()
    
        process.waitUntilExit()
    
        if process.terminationStatus == 0 {
            log.print(.info, "mounted dmg at \(mountpath)")
            return URL(fileURLWithPath: mountpath)
        } else {
            throw RuntimeError("hdiutil failed to mount dmg exited with code \(process.terminationStatus)")
        }
    }
    
    @MainActor
    func eject() throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
        process.arguments = [
            "detach",
            mountpath,
            "-quiet"
        ]
    
        try process.run()
    
        process.waitUntilExit()
    
        if process.terminationStatus == 0 {
            log.print(.info, "ejected dmg at \(mountpath)")
        } else {
            throw RuntimeError("hdiutil failed to mount dmg exited with code \(process.terminationStatus)")
        }
    }

    init(id: Int?, name: String, size: Int64, path: String, mountpath: String, keySerial: String, backuppath: String? = nil) {
        self.id = id
        self.name = name
        self.size = size
        self.path = path
        self.backuppath = backuppath
        self.mountpath = mountpath
        self.keySerial = keySerial
    }
}

struct VolumeManager {
    let usbs: USB
    let db: Database

    var vols: [Volume] = []

    mutating func reloadVols() throws {
        vols = try db.getVolumes()
    }

    func getPassword() throws -> String {
        let keySerial = try self.db.getSerial()
        var key: USBDevice? = nil

        for usb in usbs.usbDevices {
            if usb.serial == keySerial {
                key = usb
                break
            }
        }

        guard let key = key else {
            throw KeyError.keyNotInserted
        }
        
        return try key.GetSecretMessage()
    }

    @MainActor
    func makeVol(at path: String, mountPoint: String, volumeName: String, sizeMB: Int) throws -> Volume {
        var isDir: ObjCBool = true

        if FileManager.default.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue {
            throw RuntimeError("already exists")
        }

        for vol in vols {
            if volumeName == vol.name {
                throw RuntimeError("already exists")
            }
        }

        let vol = Volume(
            id: nil,
            name: volumeName,
            size: Int64(sizeMB),
            path: path,
            mountpath: mountPoint,
            keySerial: try db.getSerial()
        )

        try self.db.insertVolume(toAdd: vol)

        let dmgPath = URL(fileURLWithPath: path)
    
        let process = Process()

        process.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
        process.arguments = [
            "create",
            "-encryption", "-stdinpass",
            "-volname", volumeName,
            "-size", "\(sizeMB)M",
            "-fs", "APFS",
            "-type", "SPARSEBUNDLE",
            dmgPath.path,
            "-quiet"
        ]
    
        let inputPipe = Pipe()
        process.standardInput = inputPipe

        let password = try self.getPassword()
            
        try process.run()

        inputPipe.fileHandleForWriting.write((password).data(using: .utf8)!)
        inputPipe.fileHandleForWriting.closeFile()
    
        process.waitUntilExit()
    
        if process.terminationStatus == 0 {
            log.print(.info, "encrypted dmg created at \(dmgPath.path)")
            return vol
        } else {
            throw RuntimeError("hdiutil failed to create dmg exited with code \(process.terminationStatus)")
        }
    }

    init(usb: USB, db: Database) throws {
        self.usbs = usb
        self.db = db

        try reloadVols()
    }
}
