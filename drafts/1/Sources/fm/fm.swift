import Foundation
// hdiutil create -encryption -stdinpass -volname bine -size 1000m -fs APFS -type SPARSEBUNDLE ./bine.dmg

struct Volume {
    let id: Int?
    let name: String
    let size: Int64
    let path: String
    let mountpath: String
    let keySerial: String
}

struct VolumeManager {
    let usbs: USB
    let db: Database

    private func getPassword() throws -> String {
        let keySerial = try self.db.getSerial()
        var key: USBDevice? = nil

        for usb in usbs.usbDevices {
            if usb.serial == keySerial {
                key = usb
                break
            }
        }

        guard let key = key else {
            throw RuntimeError("key is not inserted")
        }
        
        guard let password = try self.usbs.GetSecretMessage(key, "com.corn.bine") else {
            throw RuntimeError("couldn't convert key to string")
        }

        return password
    }

    func createVol(at path: String, volumeName: String, sizeMB: Int) throws {
        var isDir: ObjCBool = true

        if FileManager.default.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue {
            throw RuntimeError("dmg exists")
        }

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
            dmgPath.path
        ]
    
        let inputPipe = Pipe()
        process.standardInput = inputPipe

        let password = try self.getPassword()
            
        try process.run()

        inputPipe.fileHandleForWriting.write((password).data(using: .utf8)!)
        inputPipe.fileHandleForWriting.closeFile()
    
        process.waitUntilExit()
    
        if process.terminationStatus == 0 {
            print("encrypted dmg created at \(dmgPath.path)")
        } else {
            throw RuntimeError("hdiutil failed to create dmg exited with code \(process.terminationStatus)")
        }
    }
    
    func mountVol(at dmgPath: String, mountpoint: String) throws -> URL?{
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
        process.arguments = [
            "attach",
            dmgPath,
            "-stdinpass",
            // "-nobrowse", // optional: hides in Finder
            "-mountpoint", mountpoint
        ]
    
        let inputPipe = Pipe()
        process.standardInput = inputPipe
        process.standardOutput = Pipe()
        process.standardError = Pipe()

        let password = try self.getPassword()

        try process.run()
    
        inputPipe.fileHandleForWriting.write((password).data(using: .utf8)!)
        inputPipe.fileHandleForWriting.closeFile()
    
        process.waitUntilExit()
    
        if process.terminationStatus == 0 {
            print("mounted dmg at \(mountpoint)")
            return URL(fileURLWithPath: mountpoint)
        } else {
            throw RuntimeError("hdiutil failed to mount dmg exited with code \(process.terminationStatus)")
        }
    }
    
    func ejectVol(at mount: String) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
        process.arguments = [
            "detach",
            mount,
        ]
    
        try process.run()
    
        process.waitUntilExit()
    
        if process.terminationStatus == 0 {
            print("ejected dmg at \(mount)")
        } else {
            throw RuntimeError("hdiutil failed to mount dmg exited with code \(process.terminationStatus)")
        }
    }

    init(usb: USB, db: Database) {
        self.usbs = usb
        self.db = db
    }
}
