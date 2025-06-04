import Cocoa
import Foundation
import SQLite
import Security

let attr = "com.corn.bine"
let dbpath = URL(filePath: "/tmp/corndeliveryutility/base.db");
let db = Database(dbpath)

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

func BasicKeySelector(_ usbs: USB, _ db: Database) throws {
    for usb in usbs.usbDevices {
        usb.prnt()
        print("-------------------------------")
    }
    
    print("Pick the drive you want:")
    if let input = readLine(), let driveNum = Int(input) {
        let drive = usbs.usbDevices[driveNum-1]
        if drive.volumetype == "APFS" {
            let res = try usbs.SetSecretMessage(drive, attr, GenerateSecurePassword(length: 52))
            guard res > 0 else {
                throw RuntimeError("some case happened where no bytes were written probably permissions or something like that")
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

@MainActor
func showInsertKey(vols: VolumeManager, dmgPath: String, mountpoint: String) async {
    let width: CGFloat = 200
    let height: CGFloat = 150
    let window = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: width, height: height),
        styleMask: [.titled, .borderless],
        backing: .buffered,
        defer: false
    )

    window.level = .modalPanel
    window.isReleasedWhenClosed = false

    if let screen = NSScreen.main {
        let screenRect = screen.visibleFrame
        window.setFrameOrigin(NSPoint(x: screenRect.minX + 10, y: screenRect.maxY + height))
    }

    // window.center()

    window.title = "🔐"
    // window.backgroundColor = .black
    
    let contentView = NSView(frame: window.contentView!.bounds)
    contentView.autoresizingMask = [.width, .height]

    // place this in center regardless of height
    let label = NSTextField(labelWithString: "insert usb key")
    label.font = NSFont.systemFont(ofSize: 16)
    label.alignment = .center
    label.sizeToFit()
    label.frame = NSRect(
        x: (width - label.frame.width) / 2,
        y: ((height - label.frame.height) / 2) + 5,
        width: label.frame.width,
        height: label.frame.height
    )
    contentView.addSubview(label)

    window.contentView = contentView
    window.makeKeyAndOrderFront(nil)

    while true {
        do {
            try vols.usbs.RefreshUSBList()
            let _ = try vols.mountVol(at: dmgPath, mountpoint: mountpoint)
            break
        } catch {
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
    }

    window.close()
}

let args = CommandLine.arguments

struct App {
    var args: [String]
    // i want to have a list of callbacks
    // i want a macro like @MainActor to define the data for these callback ergonomically things like command name and description
    // i want these all to be gathered here into a list

    func Help() {
    
    }

    init(_ args: [String]) {
        self.args = args  
        self.args.removeFirst()

        if self.args.isEmpty {
            print("must supply some option")
            self.Help()
            exit(69)
        }

        for (i, arg) in self.args.enumerated() {
            print("args \(i + 1): \(arg)")
        }
    }
}

let _ = App(args)

/* do {
    // if this throws KeyError.noUSBInserted
    let usbs = try USB()
    let _ = try SetupSerial(usbs, db)

    let vols = VolumeManager(usb: usbs, db: db)

    // im storing everything in temp but i want somewhere to store this that will stay after restarts
    let testDmg = "/tmp/EncryptedDisk.sparsebundle"
    let mp =  "/Users/crack/Thing"

    do {
        try vols.createVol(
            at: testDmg,
            volumeName: "SecretVolume",
            sizeMB: 100
        )
    } catch {
        print(error.localizedDescription)
    }

    do {
        _ = try vols.mountVol(at: testDmg, mountpoint: mp)
    } catch {
        await showInsertKey(vols: vols, dmgPath: testDmg, mountpoint: mp)
    }
} catch {
    print("error:", error)
} */

/* let alert = NSAlert()
alert.messageText = "insert key"
alert.informativeText = "pending..."
alert.alertStyle = .informational

let button = alert.addButton(withTitle: "")
button.isHidden = true

alert.runModal() */
