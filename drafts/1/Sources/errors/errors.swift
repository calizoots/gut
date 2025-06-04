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

enum DatabaseError: LocalizedError, Equatable, CustomStringConvertible {
    case noSerialFound
    case connectionFailed(reason: String)

    var description: String {
        switch self {
            case .noSerialFound:
                return "No serial number found in the database."
            case .connectionFailed(let reason):
                return "Failed to connect to the database: \(reason)"
        }
    }

    static func == (lhs: DatabaseError, rhs: DatabaseError) -> Bool {
        switch (lhs, rhs) {
            case (.noSerialFound, .noSerialFound):
                return true
            case (.connectionFailed(let a), .connectionFailed(let b)):
                return a == b
            default:
                return false
        }
    }
}
