import SQLite
import Foundation

class Database {
    var conn: Connection?

    func checkConn() throws -> Connection {
        guard let conn = self.conn else {
            throw DatabaseError.connectionFailed(reason: "conn isn't made") 
        }
        return conn
    }

    func createDB(path: URL) throws -> Bool {
        let path = path.path
        if !FileManager.default.fileExists(atPath: path) {
            do {
                let cmd = Process()
                cmd.standardOutput = .none
                cmd.standardInput = .none
                cmd.executableURL = URL(filePath: "/usr/bin/sqlite3")
                cmd.arguments = [path]
                try cmd.run()
                cmd.waitUntilExit()
                return true
            } catch {
                throw DatabaseError.dbCreationFailed(reason: error.localizedDescription)
            }
        }
        return false
    }

    func migrateDB() throws {
        let conn = try checkConn()

        try conn.execute("""
            CREATE TABLE IF NOT EXISTS usb (
                id INTEGER PRIMARY KEY CHECK(id = 1),
                serial TEXT NOT NULL
            )
        """)
        
        try conn.execute("""
            CREATE TABLE IF NOT EXISTS volumes (
                id INTEGER PRIMARY KEY,
                name TEXT NOT NULL,
                sizeM INTEGER NOT NULL,
                path TEXT NOT NULL UNIQUE,
                mountpath TEXT NOT NULL UNIQUE,
                backuppath TEXT UNIQUE,
                usb_serial TEXT NOT NULL,
                FOREIGN KEY (usb_serial) REFERENCES usb(serial)
            )
        """)
    }

    func getVolumes() throws -> [Volume] {
        let conn = try checkConn()
    
        let volumes = Table("volumes")
        let name = SQLite.Expression<String>("name")
        let size = SQLite.Expression<Int64>("sizeM")
        let volPath = SQLite.Expression<String>("path")
        let backuppath = SQLite.Expression<String?>("backuppath")
        let mountPath = SQLite.Expression<String>("mountpath")
        let keySerial = SQLite.Expression<String>("usb_serial")
    
        var results: [Volume] = []
    
        for row in try conn.prepare(volumes) {
            let volume = Volume(
                id: nil,
                name: row[name],
                size: row[size],
                path: row[volPath],
                mountpath: row[mountPath],
                keySerial: row[keySerial],
                backuppath: row[backuppath]
            )
            results.append(volume)
        }
    
        return results
    }

    func setBackupPath(of volume: Volume, to: String) throws {
        let conn = try checkConn()
        
        let volumes = Table("volumes")
        let volPath = SQLite.Expression<String>("path")
        let backuppath = SQLite.Expression<String?>("backuppath")

        let query = volumes.filter(volPath == volume.path)

        let updated = try conn.run(query.update(backuppath <- to))
        if updated == 0 {
            throw DatabaseError.queryFailed(reason: "volume with path \(volume.path) not found")
        }
    }

    func getBackupPath(of volume: Volume, to: String) throws -> String? {
        let conn = try checkConn()

        let volumes = Table("volumes")
        let volPath = SQLite.Expression<String>("path")
        let backuppath = SQLite.Expression<String?>("backuppath")

        let query = volumes.filter(volPath == volume.path)

        guard let row = try conn.pluck(query) else {
            throw DatabaseError.queryFailed(reason: "volume with path \(volume.path) not found")
        }

        return row[backuppath]
    }

    func insertVolume(toAdd: Volume) throws {
        let conn = try self.checkConn()

        let volumes = Table("volumes")
        let name = SQLite.Expression<String>("name")
        let size = SQLite.Expression<Int64>("sizeM")
        let volPath = SQLite.Expression<String>("path")
        let backuppath = SQLite.Expression<String?>("backuppath") 
        let mountPath = SQLite.Expression<String>("mountpath")
        let keySerial = SQLite.Expression<String>("usb_serial")

        try conn.run(volumes.insert(
            name <- toAdd.name,
            size <- toAdd.size,
            volPath <- toAdd.path,
            backuppath <- toAdd.backuppath,
            mountPath <- toAdd.mountpath,
            keySerial <- toAdd.keySerial
        ))
    }

    func removeVolume(toRemove: Volume) throws {
        do {
            let conn = try self.checkConn()

            let volumes = Table("volumes")
            let volPath = SQLite.Expression<String>("path")

            let query = volumes.filter(volPath == toRemove.path)
            try conn.run(query.delete())
        } catch {
            throw error
        }
    }

    func getSerial() throws -> String {
        let conn = try self.checkConn()

        let usb = Table("usb")
        let serial = SQLite.Expression<String>("serial")

        if let row = try conn.pluck(usb) {
            return row[serial]
        } else {
            throw DatabaseError.noSerialFound
        }
    }

    func setSerial(to: String) throws {
        let conn = try self.checkConn()

        let usb = Table("usb")
        let id = SQLite.Expression<Int>("id")
        let serial = SQLite.Expression<String>("serial")

        try conn.run(usb.insert(or: .replace,
            id <- 1,
            serial <- to
        ))
    }

    init(path: URL) throws {
        if try createDB(path: path) {
            let db = try Connection(path.path)
            conn = db
            try migrateDB()
        } else {
            let db = try Connection(path.path)
            conn = db
        }
    }
}
