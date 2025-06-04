import Foundation

enum LogLevel: Equatable {
    case info
    case warning
    case error
    var colorCode: String {
        switch self {
            case .error: return "\u{1B}[31m"
            case .warning: return "\u{1B}[33m"
            case .info: return "\u{1B}[34m"
        }
    }
}

struct Logger {
    var verbose = false
    private let resetCode = "\u{1B}[0m"

    func print(
        _ level: LogLevel,
        _ msg: String,
        _ args: CVarArg...,
        file: String = #file,
        line: Int = #line,
        ignoreverbose: Bool = false
    ) {
        let formatted = String(format: msg, arguments: args)
        let filename = (file as NSString).lastPathComponent

        switch level {
        case .error, .warning:
            let colPrefix: String
            if ignoreverbose {
                colPrefix = ""
            } else {
                colPrefix = "[\(level.colorCode)\(filename):\(line)\(resetCode)] "
            }
            let msg = "\(colPrefix)\(formatted)\n"
            if let data = msg.data(using: .utf8) {
                FileHandle.standardError.write(data)
            }
            fflush(stderr)

        case .info:
            if verbose && !ignoreverbose {
                let colPrefix = "[\(level.colorCode)\(filename):\(line)\(resetCode)] "
                let msg = "\(colPrefix)\(formatted)"
                Swift.print(msg)
            } else {
                Swift.print(formatted)
            }
            fflush(stdout)
        }
    }

    init(verbose: Bool = false) {
        self.verbose = verbose
    }
}
