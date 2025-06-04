import Foundation
import SQLite

struct Database {
    var conn: Connection?

    func checkConn() throws -> Connection {
        guard let conn = self.conn else {
            throw DatabaseError.connectionFailed(reason: "conn isn't made") 
        }
        return conn
    }

    func createDB(_ dbpath: URL) -> Int {
        if !FileManager.default.fileExists(atPath: dbpath.path()) {
            do {
                let cmd = Process()
                cmd.standardOutput = .none
                cmd.standardInput = .none
                cmd.executableURL = URL(filePath: "/usr/bin/sqlite3")
                cmd.arguments = [dbpath.path()]
                try cmd.run()
                cmd.waitUntilExit()
                return 1
            } catch {
                print("error creating database:", error)
                return -1
            }
        }
        return 0
    }

    func dbMigration() throws {
        do {
            let conn = try self.checkConn()

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
                    usb_serial TEXT NOT NULL,
                    FOREIGN KEY (usb_serial) REFERENCES usb(serial)
                )
            """)
        } catch {
            throw error
        }
    }

    func insertVolume(toAdd: Volume) throws {
        do {
            let conn = try self.checkConn()

            let volumes = Table("volumes")
            let name = SQLite.Expression<String>("name")
            let size = SQLite.Expression<Int64>("sizeM")
            let volPath = SQLite.Expression<String>("path")
            let mountPath = SQLite.Expression<String>("mountpath")
            let keySerial = SQLite.Expression<String>("usb_serial")

            try conn.run(volumes.insert(
                name <- toAdd.name,
                size <- toAdd.size,
                volPath <- toAdd.path,
                mountPath <- toAdd.mountpath,
                keySerial <- toAdd.keySerial
            ))
        } catch {
            throw error
        }
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
        do {
            let conn = try self.checkConn()

            let usb = Table("usb")
            let serial = SQLite.Expression<String>("serial")

            if let row = try conn.pluck(usb) {
                return row[serial]
            } else {
                throw DatabaseError.noSerialFound
            }
        } catch {
            throw error
        }
    }

    func setSerial(to: String) throws {
        do {
            let conn = try self.checkConn()

            let usb = Table("usb")
            let id = SQLite.Expression<Int>("id")
            let serial = SQLite.Expression<String>("serial")

            try conn.run(usb.insert(or: .replace,
                id <- 1,
                serial <- to
            ))
        } catch {
            throw error
        }
    }

    init(_ dbpath: URL) {
        let res = createDB(dbpath) 
        if res == 1 {
            do {
                let db = try Connection(dbpath.path())
                self.conn = db

                try self.dbMigration() 
           } catch {
                print("db error:", error)
            }
        } else if res == 0 {
            do {
                let db = try Connection(dbpath.path())
                self.conn = db
            } catch {
                print("db error:", error)
            }
        } else {
            print("failed to make db")
            exit(1)
        }
    }
}
