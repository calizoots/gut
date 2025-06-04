import AppKit
import Security

@MainActor 
func CheckArgsVolsSubCmd(_ cmdname: String, args: [String]) -> Volume? {
     if args.isEmpty {
        log.print(.error, """
            missing required arguments.

            Usage:
              vols \(cmdname) <name>

            Example:
              vols \(cmdname) test
            """, ignoreverbose: true)
        return nil
    }

    let name = args[0]
    var volume: Volume?

    for vol in volmngr.vols {
        if name == vol.name {
            volume = vol
        }
    }

    if volume == nil {
        log.print(.info, "available vols:")
        for vol in volmngr.vols {
            vol.print(log) 
            log.print(.info, String(repeating: "-----------", count: 5))
        }
        log.print(.error, "volume \(name) was not found")
        return nil
    } else {
        return volume
    }
}

@MainActor
func SetupDataDir() throws -> URL {
    let appName = "com.s.utility"
    let url = FileManager.default
        .urls(for: .applicationSupportDirectory, in: .userDomainMask)
        .first!
        .appendingPathComponent(appName, isDirectory: true)

    var isDir: ObjCBool = true
    if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
        return url
    } else {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}

@MainActor
func SetupSerial() throws {
    do {
        _ = try db.getSerial()
        return
    } catch let error as DatabaseError {
        if error == .noSerialFound {
            var device: USBDevice? = nil

            Task {
                do {
                    device = try await pickUSBUI(usb, title: "pick a usb to be the key")
                } catch let error as KeyError {
                    if error == .noUSBInserted {
                        log.print(.error, "no usbs are inserted")
                        exit(69)
                    }
                }
            }
    
            NSApplication.shared.run()
    
            if let device = device {
                if device.volumetype == "APFS" {
                    let res = try device.SetSecretMessage(data: GenerateSecurePassword(length: 52))
    
                    if res <= 0 {
                        throw RuntimeError("some case happened where no bytes were written to key probably permissions on the usb or something like that")
                    }
    
                    try db.setSerial(to: device.serial)
                } else {
                    throw RuntimeError("selected incompatible drive")
                }
            } else {
                throw RuntimeError("no usb selected shutting down")
            }
        } else {
            throw error
        }
    }
}

func CheckIfFolderExists(_ path: String, callback: @escaping (Bool, ObjCBool) -> Void) -> Bool {
    var isDir: ObjCBool = false
    let exists = FileManager.default.fileExists(atPath: path, isDirectory: &isDir)

    if !exists && !isDir.boolValue {
        callback(exists, isDir)
        return false
    } else {
        return true
    }
}

func RunRsync(from source: String, to destination: String) throws {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/rsync")
    
    // arguments for rsync:
    // -a : archive mode (recursive, preserve permissions, timestamps, etc.)
    // -v : verbose
    // --delete : delete files in destination not present in source (optional)
    process.arguments = ["-av", "--delete", source, destination]
    
    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = pipe
    
    try process.run()
    process.waitUntilExit()
    
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    if let output = String(data: data, encoding: .utf8) {
        print(output)
    }
    
    if process.terminationStatus != 0 {
        throw NSError(domain: "rsync", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: "rsync failed"])
    }
}

func GenerateSecurePassword(length: Int = 20) -> String {
    let charset = Array("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*()-_=+[]{}|;:,.<>?/~`")
    var res = ""

    for _ in 0..<length {
        var byte: UInt8 = 0
        let status = SecRandomCopyBytes(kSecRandomDefault, 1, &byte)

        if status != errSecSuccess {
            fatalError("Failed to generate secure random byte.")
        }

        res.append(charset[Int(byte) % charset.count])
    }
    return res
}
