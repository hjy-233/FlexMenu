import Foundation

@MainActor
@main
enum FlexMenuMain {
    static func main() {
        let arguments = Array(CommandLine.arguments.dropFirst())
        if arguments.isEmpty {
            FlexMenuApp.main()
            return
        }
        do {
            try FlexMenuCLI.run(arguments)
        } catch {
            FileHandle.standardError.write(Data("flexmenu: \(error.localizedDescription)\n".utf8))
            exit(EXIT_FAILURE)
        }
    }
}

@MainActor
enum FlexMenuCLI {
    static func run(_ arguments: [String]) throws {
        guard let command = arguments.first else { return }
        let rest = Array(arguments.dropFirst())
        switch command {
        case "--service": ServiceRuntime.run()
        case "menu": try showMenu(rest)
        case "run": try runAction(rest)
        case "config": try config(rest)
        case "service": try ServiceControl.run(rest)
        case "--version", "version": print("FlexMenu 1.0")
        case "--help", "help": print(help)
        default: throw usage("未知命令：\(command)")
        }
    }

    private static func showMenu(_ arguments: [String]) throws {
        guard arguments.isEmpty else { throw usage("menu 不接受参数") }
        try ServiceIPC.send(.showMenu)
    }

    private static func runAction(_ arguments: [String]) throws {
        guard let identifier = arguments.first else {
            throw usage("用法：flexmenu run <ID> -- [文件路径...]")
        }
        let remaining = Array(arguments.dropFirst())
        guard remaining.isEmpty || remaining.first == "--" else {
            throw usage("文件路径前需要 --")
        }
        let paths = remaining.isEmpty ? [] : Array(remaining.dropFirst())
        let configuration = try ConfigurationStore.loadSnapshot()
        let context = MenuContext(
            mode: paths.isEmpty ? "normal" : "dragging",
            frontmostBundleID: nil,
            filePaths: paths,
            text: nil,
            url: nil
        )
        let items = try MenuScripts.resolve(configuration: configuration, context: context)
        guard let item = items.first(where: { $0.id == identifier }) else {
            throw FlexMenuFailure.message("找不到操作：\(identifier)")
        }
        let result = try MenuScripts.run(
            item: item,
            configuration: configuration,
            context: context
        )
        FileHandle.standardOutput.write(Data(result.output.utf8))
        FileHandle.standardError.write(Data(result.error.utf8))
        if result.status != 0 {
            exit(result.status)
        }
    }

    private static func config(_ arguments: [String]) throws {
        guard let command = arguments.first else { throw usage("缺少 config 子命令") }
        let rest = Array(arguments.dropFirst())
        switch command {
        case "init":
            guard rest.isEmpty else { throw usage("config init 不接受参数") }
            try ConfigurationStore.initialize()
            print("已创建配置：\(ConfigurationStore.scriptURL.path)")
        case "path":
            guard rest.isEmpty else { throw usage("config path 不接受参数") }
            print(ConfigurationStore.scriptURL.path)
        case "check":
            guard rest.count <= 1 else { throw usage("config check [路径]") }
            let url = rest.first.map { URL(fileURLWithPath: $0) }
                ?? ConfigurationStore.scriptURL
            let configuration = try ConfigurationLoader.load(at: url)
            try MenuScripts.check(configuration: configuration, sampleFile: url.path)
            print("配置与菜单输出有效：\(configuration.menuScripts.count) 个菜单脚本")
        case "shortcut": try emitShortcut(rest)
        case "menu": try emitMenu(rest)
        default: throw usage("未知 config 命令：\(command)")
        }
    }

    private static func emitShortcut(_ arguments: [String]) throws {
        let options = try parseOptions(arguments)
        guard Set(options.keys).isSubset(of: ["key", "modifiers"]) else {
            throw usage("config shortcut 含未知选项")
        }
        guard let key = options["key"], let modifiers = options["modifiers"] else {
            throw usage("config shortcut --key <键> --modifiers <修饰键列表>")
        }
        try ConfigurationStore.update(.shortcut(
            key: key,
            modifiers: modifiers.split(separator: ",").map(String.init)
        ))
    }

    private static func emitMenu(_ arguments: [String]) throws {
        guard arguments.first == "add" else { throw usage("config menu add ...") }
        let options = try parseOptions(Array(arguments.dropFirst()))
        guard Set(options.keys).isSubset(of: ["script"]) else {
            throw usage("config menu add 含未知选项")
        }
        guard let path = options["script"], !path.isEmpty else {
            throw usage("config menu add --script <菜单脚本>")
        }
        try ConfigurationStore.update(.addMenu(path: path))
    }

    private static func parseOptions(_ arguments: [String]) throws -> [String: String] {
        guard arguments.count.isMultiple(of: 2) else {
            throw usage("选项必须成对出现")
        }
        var options: [String: String] = [:]
        for index in stride(from: 0, to: arguments.count, by: 2) {
            let name = arguments[index]
            guard name.hasPrefix("--"), options[String(name.dropFirst(2))] == nil else {
                throw usage("无效或重复的选项：\(name)")
            }
            options[String(name.dropFirst(2))] = arguments[index + 1]
        }
        return options
    }

    private static func usage(_ message: String) -> FlexMenuFailure {
        .message(message)
    }

    private static var help: String {
        "cli.help"
    }
}
