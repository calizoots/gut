import Foundation
import AppKit
import Cocoa

NSApplication.shared.setActivationPolicy(.accessory)
var log = Logger()

log.verbose = false

let usb = USB()
let volmngr: VolumeManager
let datadir: URL
let db: Database

do {
    datadir = try SetupDataDir()
    db = try Database(path: datadir.appending(path: "base.db"))
    try SetupSerial()
    volmngr = try VolumeManager(usb: usb, db: db)
} catch {
    log.print(.error, "error while setting up: \(error)")
    exit(69)
}

var app = Cli()

app.registerCommand("vols", description: "manage volumes") { args, slf async in
    slf.registerSubCommand("list", description: "list out volumes") { args, slf  in
        if volmngr.vols.isEmpty {
            log.print(.error, "there is no volumes here")
        }

        for vol in volmngr.vols {
            vol.print(log) 
            log.print(.info, String(repeating: "-----------", count: 5))
        }
    }

    slf.registerSubCommand("backup", description: "makes a backup of a volume", callback: BackupCmd)

    slf.registerSubCommand("mount", description: "mount a volume", callback: MountCmd)

    slf.registerSubCommand("eject", description: "eject a volume", callback: EjectCmd)
    
    slf.registerSubCommand("create", description: "creates a new encrypted volume", callback: CreateCmd)

    await slf.RunSubCommand(args: args)
}

await app.Run()
