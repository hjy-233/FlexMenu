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
        try JSONDecoder().decode(
            MenuConfiguration.self,
            from: Data(contentsOf: snapshotURL)
        )
    }

    static func save(_ config: MenuConfiguration) throws {
        let directory = snapshotURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        try JSONEncoder().encode(config).write(to: snapshotURL, options: .atomic)
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
            throw FlexMenuFailure.message("配置文件已经存在，不会覆盖")
        }
        let action = "#!/bin/zsh\nopen -a Terminal\n"
        try writeExample(action, to: actionURL)
        let reveal = "#!/bin/zsh\nfor file in \"$@\"; do\n    open -R -- \"$file\"\ndone\n"
        try writeExample(reveal, to: revealURL)
        let menu = """
        #!/bin/zsh
        cat <<'JSON'
        {"mode":"normal","items":[{"id":"terminal","title":"终端","action":"actions/terminal.sh"}]}
        JSON

        """
        try writeExample(menu, to: menuURL)
        let dragging = """
        #!/bin/zsh
        if (( $# == 0 )); then
            print -r -- '{"mode":"dragging","items":[]}'
            exit 0
        fi
        print -r -- '{"mode":"dragging","items":[{"id":"reveal","title":"在 Finder 中定位","action":"actions/reveal.sh"}]}'

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
            throw FlexMenuFailure.message("配置不存在：\(url.path)")
        }

        let executable = Bundle.main.executableURL?.path ?? CommandLine.arguments[0]
        let command = "set -e; function flexmenu() { \"$FLEXMENU_EXECUTABLE\" \"$@\"; }; source \"$1\""
        let result = try ShellProcess.run(
            executable: "/bin/zsh",
            arguments: ["-c", command, "flexmenurc", url.path],
            environment: ["FLEXMENU_EXECUTABLE": executable],
            input: nil,
            timeout: 10
        )
        guard result.status == 0 else {
            throw FlexMenuFailure.message("配置执行失败（状态 \(result.status)）：\(result.error)")
        }

        var config = MenuConfiguration()
        config.scriptDirectory = url.deletingLastPathComponent().path
        for line in result.output.split(separator: "\n") {
            let instruction = try JSONDecoder().decode(
                ConfigurationInstruction.self,
                from: Data(line.utf8)
            )
            try apply(instruction, to: &config)
        }
        guard !config.menuScripts.isEmpty else {
            throw FlexMenuFailure.message("配置没有菜单脚本")
        }
        try Shortcut.validate(config)
        return config
    }

    private static func apply(
        _ instruction: ConfigurationInstruction,
        to config: inout MenuConfiguration
    ) throws {
        switch instruction.kind {
        case "shortcut":
            config.shortcutKey = instruction.key
            config.shortcutModifiers = instruction.modifiers ?? []
        case "menu":
            guard let script = instruction.script else {
                throw FlexMenuFailure.message("菜单配置缺少脚本")
            }
            guard !config.menuScripts.contains(where: { $0.path == script.path }) else {
                throw FlexMenuFailure.message("重复的菜单脚本：\(script.path)")
            }
            guard FileManager.default.fileExists(
                atPath: config.scriptURL(for: script.path).path
            ) else {
                throw FlexMenuFailure.message("菜单脚本不存在：\(script.path)")
            }
            config.menuScripts.append(script)
        default:
            throw FlexMenuFailure.message("未知配置指令：\(instruction.kind)")
        }
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

struct ConfigurationInstruction: Codable {
    let kind: String
    let key: String?
    let modifiers: [String]?
    let script: MenuScript?
}
