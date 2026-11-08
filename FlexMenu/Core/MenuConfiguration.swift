import AppKit
import Foundation

enum FlexMenuFailure: LocalizedError {
    case message(String)

    var errorDescription: String? {
        switch self {
        case let .message(value): value
        }
    }
}

struct MenuContext: Codable {
    let mode: String
    let frontmostBundleID: String?
    let filePaths: [String]
    let text: String?
    let url: String?

    static func normal() -> MenuContext {
        MenuContext(
            mode: "normal",
            frontmostBundleID: NSWorkspace.shared.frontmostApplication?.bundleIdentifier,
            filePaths: [],
            text: nil,
            url: nil
        )
    }

    static func dragging(_ pasteboard: NSPasteboard) -> MenuContext {
        let paths = (pasteboard.readObjects(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]
        ) as? [URL] ?? []).map(\.path)

        return MenuContext(
            mode: "dragging",
            frontmostBundleID: NSWorkspace.shared.frontmostApplication?.bundleIdentifier,
            filePaths: paths,
            text: pasteboard.string(forType: .string),
            url: pasteboard.string(forType: .URL)
        )
    }
}

struct MenuItemDefinition: Codable {
    let id: String
    let title: String
    let action: String
}

struct MenuScript: Codable {
    let path: String
}

struct MenuOutput: Codable {
    let mode: String?
    let items: [MenuItemDefinition]
}

struct MenuConfiguration: Codable {
    var scriptDirectory: String = ConfigurationStore.scriptURL.deletingLastPathComponent().path
    var shortcutKey: String?
    var shortcutModifiers: [String] = []
    var menuScripts: [MenuScript] = []
}

enum ConfigurationChange: Codable {
    case shortcut(key: String, modifiers: [String])
    case addMenu(path: String)

    func apply(to configuration: inout MenuConfiguration) throws {
        switch self {
        case let .shortcut(key, modifiers):
            configuration.shortcutKey = key
            configuration.shortcutModifiers = modifiers
            try Shortcut.validate(configuration)
        case let .addMenu(path):
            guard !configuration.menuScripts.contains(where: { $0.path == path }) else {
                throw FlexMenuFailure.message(L10n.format("重复的菜单脚本：%@", path))
            }
            guard FileManager.default.fileExists(
                atPath: configuration.scriptURL(for: path).path
            ) else {
                throw FlexMenuFailure.message(L10n.format("菜单脚本不存在：%@", path))
            }
            configuration.menuScripts.append(MenuScript(path: path))
        }
    }
}

enum ConfigurationStore {
    static var scriptURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/flexmenu/flexmenurc")
    }

    static var snapshotURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/FlexMenu/config.json")
    }

    static func loadSnapshot() throws -> MenuConfiguration {
        try load(at: snapshotURL)
    }

    static func load(at url: URL) throws -> MenuConfiguration {
        try JSONDecoder().decode(
            MenuConfiguration.self,
            from: Data(contentsOf: url)
        )
    }

    static func save(_ config: MenuConfiguration, to url: URL = snapshotURL) throws {
        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        try JSONEncoder().encode(config).write(to: url, options: .atomic)
    }

    static func update(_ change: ConfigurationChange) throws {
        if let stagingPath = ProcessInfo.processInfo.environment["FLEXMENU_CONFIG_STAGE"] {
            let url = URL(fileURLWithPath: stagingPath)
            var configuration = try load(at: url)
            try change.apply(to: &configuration)
            try save(configuration, to: url)
        } else {
            try ServiceIPC.send(.configuration(change))
        }
    }

    static func initialize() throws {
        let directory = scriptURL.deletingLastPathComponent()
        let actionURL = directory.appendingPathComponent("actions/terminal.sh")
        let revealURL = directory.appendingPathComponent("actions/reveal.sh")
        let menuURL = directory.appendingPathComponent("menus/normal.sh")
        let draggingURL = directory.appendingPathComponent("menus/dragging.sh")
        guard !FileManager.default.fileExists(atPath: scriptURL.path),
              !FileManager.default.fileExists(atPath: actionURL.path),
              !FileManager.default.fileExists(atPath: revealURL.path),
              !FileManager.default.fileExists(atPath: menuURL.path),
              !FileManager.default.fileExists(atPath: draggingURL.path)
        else {
            throw FlexMenuFailure.message(L10n.text("配置文件已经存在，不会覆盖"))
        }
        let action = "#!/bin/zsh\nopen -a Terminal\n"
        try writeExample(action, to: actionURL)
        let reveal = "#!/bin/zsh\nfor file in \"$@\"; do\n    open -R -- \"$file\"\ndone\n"
        try writeExample(reveal, to: revealURL)
        let terminalTitle = L10n.text("终端")
        let menu = """
        #!/bin/zsh
        cat <<'JSON'
        {"mode":"normal","items":[{"id":"terminal","title":"\(terminalTitle)","action":"actions/terminal.sh"}]}
        JSON

        """
        try writeExample(menu, to: menuURL)
        let revealTitle = L10n.text("在 Finder 中定位")
        let revealItem = "{\"mode\":\"dragging\",\"items\":[{\"id\":\"reveal\"," +
            "\"title\":\"\(revealTitle)\",\"action\":\"actions/reveal.sh\"}]}"
        let dragging = """
        #!/bin/zsh
        if (( $# == 0 )); then
            print -r -- '{"mode":"dragging","items":[]}'
            exit 0
        fi
        print -r -- '\(revealItem)'

        """
        try writeExample(dragging, to: draggingURL)
        let configuration = """
        #!/bin/zsh
        flexmenu config shortcut --key space --modifiers command,option
        flexmenu config menu add --script menus/normal.sh
        flexmenu config menu add --script menus/dragging.sh

        """
        try writeExample(configuration, to: scriptURL)
    }

    private static func writeExample(_ content: String, to url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data(content.utf8).write(to: url, options: .atomic)
    }
}

enum ConfigurationLoader {
    static func load(at url: URL = ConfigurationStore.scriptURL) throws -> MenuConfiguration {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw FlexMenuFailure.message(L10n.format("配置不存在：%@", url.path))
        }

        let executable = Bundle.main.executableURL?.path ?? CommandLine.arguments[0]
        let stagedURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("flexmenu-config-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: stagedURL) }
        var initial = MenuConfiguration()
        initial.scriptDirectory = url.deletingLastPathComponent().path
        try ConfigurationStore.save(initial, to: stagedURL)

        let command = "set -e; function flexmenu() { \"$FLEXMENU_EXECUTABLE\" \"$@\"; }; source \"$1\""
        let result = try ShellProcess.run(
            executable: "/bin/zsh",
            arguments: ["-c", command, "flexmenurc", url.path],
            environment: [
                "FLEXMENU_EXECUTABLE": executable,
                "FLEXMENU_CONFIG_STAGE": stagedURL.path
            ],
            input: nil,
            timeout: 10
        )
        guard result.status == 0 else {
            throw FlexMenuFailure.message(L10n.format("配置执行失败（状态 %d）：%@", result.status, result.error))
        }

        let config = try ConfigurationStore.load(at: stagedURL)
        guard !config.menuScripts.isEmpty else {
            throw FlexMenuFailure.message(L10n.text("配置没有菜单脚本"))
        }
        try Shortcut.validate(config)
        return config
    }
}

extension MenuConfiguration {
    func scriptURL(for path: String) -> URL {
        if path.hasPrefix("/") {
            return URL(fileURLWithPath: path)
        }
        return URL(fileURLWithPath: scriptDirectory).appendingPathComponent(path)
    }
}
