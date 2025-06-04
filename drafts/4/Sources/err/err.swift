import Foundation

struct RuntimeError: LocalizedError {
    let description: String

    init(_ description: String) {
        self.description = description
    }

    var errorDescription: String? {
        description
    }
}

enum KeyError: LocalizedError, Equatable, CustomStringConvertible {
    case keyNotInserted
    case noUSBInserted

    var description: String {
        switch self {
            case .keyNotInserted:
                return "the key is not inserted"
            case .noUSBInserted:
                return "no usbs inserted"
        }
    }

    static func == (lhs: KeyError, rhs: KeyError) -> Bool {
        switch (lhs, rhs) {
            case (.keyNotInserted, .keyNotInserted):
                return true
            case (.noUSBInserted, .noUSBInserted):
                return true
            default:
                return false
        }
    }
}

enum DatabaseError: LocalizedError, Equatable, CustomStringConvertible {
    case noSerialFound
    case dbCreationFailed(reason: String)
    case queryFailed(reason: String)
    case connectionFailed(reason: String)

    var description: String {
        switch self {
            case .noSerialFound:
                return "No serial number found in the database."
            case .dbCreationFailed(let reason):
                return "error creating database: \(reason)"
            case .connectionFailed(let reason):
                return "Failed to connect to the database: \(reason)"
            case .queryFailed(let reason):
                return "Failed to connect to the database: \(reason)"
        }
    }

    static func == (lhs: DatabaseError, rhs: DatabaseError) -> Bool {
        switch (lhs, rhs) {
            case (.noSerialFound, .noSerialFound):
                return true
            case (.connectionFailed, .connectionFailed):
                return true
            case (.dbCreationFailed, .dbCreationFailed):
                return true
            case (.queryFailed, .queryFailed):
                return true
            default:
                return false
        }
    }
}
