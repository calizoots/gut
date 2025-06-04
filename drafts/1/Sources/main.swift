import Foundation
import SQLite

let attr = "com.corn.bine"
let dbpath = URL(filePath: "/tmp/corndeliveryutility/base.db");
let db = Database(dbpath)

func BasicKeySelector(_ usbs: USB, _ db: Database) throws {
    for usb in usbs.usbDevices {
        usb.prnt()
        print("-------------------------------")
    }
    
    print("Pick the drive you want:")
    if let input = readLine(), let driveNum = Int(input) {
        let drive = usbs.usbDevices[driveNum-1]
        if drive.volumetype == "APFS" {
            let res = try usbs.SetSecretMessage(drive, attr, "fook off will ya") 
            guard res > 0 else {
                throw RuntimeError("some case happened where no bytes where written properly permission or something like that")
            }

            try db.setSerial(to: drive.serial)

            if let message = try usbs.GetSecretMessage(drive, attr) {
                print("read from xattr:", message)
            }
        } else {
            throw RuntimeError("incompatible drive")
        }
    } else {
        throw RuntimeError("invalid number.")
    }
}

func SetupSerial(_ usbs: USB, _ db: Database) throws -> String {
    do {
        return try db.getSerial()
    } catch let error as DatabaseError {
        if error == DatabaseError.noSerialFound {
            try BasicKeySelector(usbs, db)
            return try db.getSerial()
        } else {
            throw error
        }
    } catch {
        throw error
    }
}

do {
    let usbs = try USB()
    let _ = try SetupSerial(usbs, db)

    let vols = VolumeManager(usb: usbs, db: db)

    do {
        try vols.createVol(
            at: "/tmp/EncryptedDisk.sparsebundle",
            volumeName: "SecretVolume",
            sizeMB: 100
        )
    } catch {
        print(error.localizedDescription)
    }

    let _ = try vols.mountVol(
        at: "/tmp/EncryptedDisk.sparsebundle", 
        mountpoint: "/Users/crack/Thing"
    )
} catch {
    print("error:", error)
}
