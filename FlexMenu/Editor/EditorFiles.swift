import Foundation

enum EditorFiles {
    struct ActionCreation {
        let id: String
        let title: String
        let name: String
        let source: String
        let script: MenuScript
        let template: VisualMenuScript
        let mode: String
        let items: [EditableMenuItem]
        let configuration: MenuConfiguration
    }

    static func saveMenu(
        _ text: String,
        script: MenuScript,
        configuration: MenuConfiguration
    ) throws {
        let url = configuration.scriptURL(for: script.path)
        let temporary = url.deletingLastPathComponent()
            .appendingPathComponent(".flexmenu-edit-\(UUID().uuidString).sh")
        try Data(text.utf8).write(to: temporary, options: .atomic)
        defer { try? FileManager.default.removeItem(at: temporary) }

        let candidate = MenuScript(path: temporary.path)
        let contexts = [MenuContext.normal(), sampleFileContext()]
        for context in contexts {
            _ = try MenuScripts.preview(
                script: candidate,
                configuration: configuration,
                context: context
            )
        }
        try Data(text.utf8).write(to: url, options: .atomic)
    }

    static func saveAction(_ text: String, path: String, configuration: MenuConfiguration) throws {
        let url = configuration.scriptURL(for: path)
        try validateAction(text, in: url.deletingLastPathComponent())
        try Data(text.utf8).write(to: url, options: .atomic)
    }

    static func createMenu(name: String, mode: String) throws -> MenuScript {
        guard validName(name), ["normal", "dragging"].contains(mode) else {
            throw FlexMenuFailure.message("菜单名称或模式无效")
        }
        let script = MenuScript(path: "menus/\(name).sh")
        let configuration = try ConfigurationStore.loadSnapshot()
        let url = configuration.scriptURL(for: script.path)
        let template = VisualMenuScript(kind: .plain, output: MenuOutput(mode: mode, items: []))
        let source = try template.render(mode: mode, items: [])
        let original = try Data(contentsOf: ConfigurationStore.scriptURL)
        guard let configurationSource = String(data: original, encoding: .utf8) else {
            throw FlexMenuFailure.message("flexmenurc 不是 UTF-8 文件")
        }
        try Data(source.utf8).write(to: url, options: .withoutOverwriting)
        var accepted = false
        defer {
            if !accepted {
                try? original.write(to: ConfigurationStore.scriptURL, options: .atomic)
                try? FileManager.default.removeItem(at: url)
            }
        }
        let command = "flexmenu config menu add --script \(script.path)"
        let updated = configurationSource.trimmingCharacters(in: .newlines) + "\n" + command + "\n"
        try Data(updated.utf8).write(to: ConfigurationStore.scriptURL, options: .atomic)
        let loaded = try ConfigurationLoader.load()
        guard loaded.menuScripts.contains(where: { $0.path == script.path }) else {
            throw FlexMenuFailure.message("新菜单未在 flexmenurc 中生效")
        }
        try ServiceIPC.send(.configuration(.addMenu(path: script.path)))
        accepted = true
        return script
    }

    static func createAction(_ request: ActionCreation) throws -> String {
        let id = request.id
        let title = request.title
        let name = request.name
        let source = request.source
        guard !id.isEmpty, !title.isEmpty, validName(name),
              !source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            throw FlexMenuFailure.message("请填写操作标识、名称、脚本名和脚本内容")
        }
        guard !request.items.contains(where: { $0.id == id }) else {
            throw FlexMenuFailure.message("重复的操作标识：\(id)")
        }
        let action = "actions/\(name).sh"
        let url = request.configuration.scriptURL(for: action)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try validateAction(source, in: url.deletingLastPathComponent())
        try Data(source.utf8).write(to: url, options: .withoutOverwriting)
        var accepted = false
        defer {
            if !accepted {
                try? FileManager.default.removeItem(at: url)
            }
        }
        var updated = request.items
        updated.append(EditableMenuItem(MenuItemDefinition(id: id, title: title, action: action)))
        let menuSource = try request.template.render(mode: request.mode, items: updated)
        try saveMenu(menuSource, script: request.script, configuration: request.configuration)
        accepted = true
        return menuSource
    }

    private static func validName(_ name: String) -> Bool {
        !name.isEmpty && name.unicodeScalars.allSatisfy {
            CharacterSet.alphanumerics.contains($0) || $0 == "-" || $0 == "_"
        }
    }

    private static func validateAction(_ text: String, in directory: URL) throws {
        let temporary = directory
            .appendingPathComponent(".flexmenu-edit-\(UUID().uuidString).sh")
        try Data(text.utf8).write(to: temporary, options: .atomic)
        defer { try? FileManager.default.removeItem(at: temporary) }

        let result = try ShellProcess.run(
            executable: "/bin/zsh",
            arguments: ["-n", temporary.path],
            input: nil,
            timeout: 3
        )
        guard result.status == 0 else {
            throw FlexMenuFailure.message("动作脚本语法错误：\(result.error)")
        }
    }

    static func saveShortcut(key: String, modifiers: [String]) throws {
        var proposed = try ConfigurationStore.loadSnapshot()
        proposed.shortcutKey = key
        proposed.shortcutModifiers = modifiers
        try Shortcut.validate(proposed)

        let url = ConfigurationStore.scriptURL
        let original = try Data(contentsOf: url)
        guard let source = String(data: original, encoding: .utf8) else {
            throw FlexMenuFailure.message("flexmenurc 不是 UTF-8 文件")
        }
        let marker = "# flexmenu editor shortcut"
        let lines = source.split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.hasSuffix(marker) }
        let command = "flexmenu config shortcut --key \(key) --modifiers \(modifiers.joined(separator: ",")) \(marker)"
        let updated = lines.joined(separator: "\n")
            .trimmingCharacters(in: .newlines) + "\n" + command + "\n"

        try Data(updated.utf8).write(to: url, options: .atomic)
        var accepted = false
        defer {
            if !accepted {
                try? original.write(to: url, options: .atomic)
            }
        }
        let loaded = try ConfigurationLoader.load()
        guard loaded.shortcutKey == key, loaded.shortcutModifiers == modifiers else {
            throw FlexMenuFailure.message("快捷键设置未在 flexmenurc 中生效")
        }
        try ServiceIPC.send(.configuration(.shortcut(key: key, modifiers: modifiers)))
        accepted = true
    }

    static func sampleFileContext() -> MenuContext {
        MenuContext(
            mode: "dragging",
            frontmostBundleID: nil,
            filePaths: [ConfigurationStore.scriptURL.path],
            text: nil,
            url: nil
        )
    }
}
