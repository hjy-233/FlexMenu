import Foundation

enum ServiceControl {
    private static let label = "org.dcstudio.FlexMenu.service"

    private static var agentURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/\(label).plist")
    }

    private static var target: String {
        "gui/\(getuid())/\(label)"
    }

    static func startIfNeeded() throws {
        guard !isLoaded else { return }
        if !FileManager.default.fileExists(atPath: ConfigurationStore.scriptURL.path) {
            try ConfigurationStore.initialize()
        }
        try run(["start"])
    }

    static func stopIfNeeded() throws {
        guard isLoaded else { return }
        try run(["stop"])
    }

    static func run(_ arguments: [String]) throws {
        guard arguments.count == 1, let command = arguments.first else {
            throw FlexMenuFailure.message("用法：flexmenu service start|restart|stop|status")
        }
        switch command {
        case "start":
            guard !isLoaded else { throw FlexMenuFailure.message("服务已经启动") }
            let configuration = try ConfigurationLoader.load()
            try start(with: configuration)
        case "restart":
            let configuration = try ConfigurationLoader.load()
            try Shortcut.validate(configuration)
            if isLoaded {
                try stop()
            }
            try start(with: configuration)
        case "stop": try stop()
        case "status": print(isRunning ? "服务运行中" : "服务未运行")
        default: throw FlexMenuFailure.message("未知 service 命令：\(command)")
        }
    }

    static var isRunning: Bool {
        let result = try? ShellProcess.run(
            executable: "/bin/launchctl",
            arguments: ["print", target],
            input: nil,
            timeout: 3
        )
        return result?.status == 0 && result?.output.contains("state = running") == true
    }

    private static var isLoaded: Bool {
        let result = try? ShellProcess.run(
            executable: "/bin/launchctl",
            arguments: ["print", target],
            input: nil,
            timeout: 3
        )
        return result?.status == 0
    }

    private static func start(with configuration: MenuConfiguration) throws {
        try Shortcut.validate(configuration)
        guard let executable = Bundle.main.executableURL else {
            throw FlexMenuFailure.message("找不到 FlexMenu 可执行文件")
        }
        try ConfigurationStore.save(configuration)
        try FileManager.default.createDirectory(
            at: agentURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let propertyList: [String: Any] = [
            "Label": label,
            "ProgramArguments": [executable.path, "--service"],
            "RunAtLoad": true,
            "KeepAlive": true,
            "LimitLoadToSessionType": "Aqua"
        ]
        let data = try PropertyListSerialization.data(
            fromPropertyList: propertyList,
            format: .xml,
            options: 0
        )
        try data.write(to: agentURL, options: .atomic)
        let result = try launchctl(["bootstrap", "gui/\(getuid())", agentURL.path])
        guard result.status == 0 else {
            throw FlexMenuFailure.message("启动服务失败：\(result.error)")
        }
        guard ServiceIPC.waitUntilReady(timeout: 5) else {
            throw FlexMenuFailure.message("服务已启动，但命令端口未就绪")
        }
        print("服务已启动")
    }

    private static func stop() throws {
        guard isLoaded else { throw FlexMenuFailure.message("服务未运行") }
        let result = try launchctl(["bootout", target])
        guard result.status == 0 else {
            throw FlexMenuFailure.message("停止服务失败：\(result.error)")
        }
        try? FileManager.default.removeItem(at: agentURL)
        print("服务已停止")
    }

    private static func launchctl(_ arguments: [String]) throws -> ShellResult {
        try ShellProcess.run(
            executable: "/bin/launchctl",
            arguments: arguments,
            input: nil,
            timeout: 5
        )
    }
}
