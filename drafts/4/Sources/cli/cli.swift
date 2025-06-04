import Foundation

@MainActor
class Command {
    let appName: String
    let name: String
    let description: String
    let callback: ([String], Command) async -> Void
    var commands: [String: Command] = [:]

    func registerSubCommand(_ name: String, description: String, callback: @escaping ([String], Command) async -> Void) {
        commands[name] = Command(appName: self.appName, name: name, description: description, callback: callback)
    }

    func printHelp() {
        print("sub commands help")
        if commands.isEmpty {
            log.print(.error, "no commands exist")
            return
        }

        log.print(.info, "./\(appName) \(name) <command>", ignoreverbose: true)

        for (_, cmd) in commands {
            log.print(.info, "  \(cmd.name): \(cmd.description)", ignoreverbose: true)
        }
    }

    func RunSubCommand(args: [String]) async {
        if let reqCmd = args.first {
            if reqCmd == "help" {
                printHelp()
                return
            }
            let remainingArgs = Array(args.dropFirst())
            if let cmd = commands[reqCmd] {
                await cmd.callback(remainingArgs, cmd)
            } else {
                log.print(.error, "unrecognised command: \(reqCmd)", ignoreverbose: true)
                printHelp()
            }
        } else {
            printHelp()
            exit(69)
        }
    }

    init(appName: String, name: String, description: String, callback: @escaping ([String], Command) async -> Void) {
        self.name = name
        self.description = description
        self.callback = callback
        self.appName = appName
    }
}

@MainActor
class Cli {
    let name: String
    var args: [String]
    var commands: [String: Command] = [:]

    func registerCommand(_ name: String, description: String, callback: @escaping ([String], Command) async -> Void) {
        commands[name] = Command(appName: self.name, name: name, description: description, callback: callback)
    }

    func printHelp() {
        if commands.isEmpty {
            log.print(.error, "no commands exist")
            return
        }

        log.print(.info, "./\(name) <command>", ignoreverbose: true)

        for (_, cmd) in commands {
            log.print(.info, "  \(cmd.name): \(cmd.description)", ignoreverbose: true)
        }
    }

    func Run() async {
        if let reqCmd = args.first {
            if reqCmd == "help" {
                printHelp()
                return
            }
            let remainingArgs = Array(args.dropFirst())
            if let cmd = commands[reqCmd] {
                await cmd.callback(remainingArgs, cmd)
            } else {
                log.print(.error, "unrecognised command: \(reqCmd)", ignoreverbose: true)
                printHelp()
            }
        } else {
            printHelp()
        }
    }
    
    init() {
        self.args = CommandLine.arguments
        self.name = URL(fileURLWithPath: CommandLine.arguments[0]).lastPathComponent
        
        args.removeFirst()
    }
}
