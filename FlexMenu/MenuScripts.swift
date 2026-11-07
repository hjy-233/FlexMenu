import Foundation

enum MenuScripts {
    static func resolve(
        configuration: MenuConfiguration,
        context: MenuContext
    ) throws -> [MenuItemDefinition] {
        let input = try JSONEncoder().encode(context)
        for script in configuration.menuScripts {
            let output = try load(script, configuration: configuration, context: context, input: input)
            if let mode = output.mode {
                guard mode == context.mode else { continue }
            }
            guard !output.items.isEmpty else { continue }
            return output.items
        }
        return []
    }

    static func check(configuration: MenuConfiguration, sampleFile: String) throws {
        let contexts = [
            MenuContext(
                mode: "normal",
                frontmostBundleID: nil,
                filePaths: [],
                text: nil,
                url: nil
            ),
            MenuContext(
                mode: "dragging",
                frontmostBundleID: nil,
                filePaths: [sampleFile],
                text: nil,
                url: nil
            )
        ]
        for context in contexts {
            let input = try JSONEncoder().encode(context)
            for script in configuration.menuScripts {
                _ = try load(script, configuration: configuration, context: context, input: input)
            }
        }
    }

    private static func load(
        _ script: MenuScript,
        configuration: MenuConfiguration,
        context: MenuContext,
        input: Data
    ) throws -> MenuOutput {
        let result = try ShellProcess.run(
            executable: "/bin/zsh",
            arguments: [configuration.scriptURL(for: script.path).path] + context.filePaths,
            input: input,
            timeout: 3
        )
        guard result.status == 0 else {
            throw FlexMenuFailure.message(
                "菜单脚本失败（\(script.path)，状态 \(result.status)）：\(result.error)"
            )
        }
        let output: MenuOutput
        do {
            output = try JSONDecoder().decode(MenuOutput.self, from: Data(result.output.utf8))
        } catch {
            throw FlexMenuFailure.message("菜单脚本输出无效（\(script.path)）：\(error.localizedDescription)")
        }
        if let mode = output.mode, !["normal", "dragging"].contains(mode) {
            throw FlexMenuFailure.message("菜单模式无效：\(script.path)")
        }
        try validate(output.items, script: script, configuration: configuration)
        return output
    }

    private static func validate(
        _ items: [MenuItemDefinition],
        script: MenuScript,
        configuration: MenuConfiguration
    ) throws {
        var ids = Set<String>()
        for item in items {
            guard !item.id.isEmpty, !item.title.isEmpty, !item.action.isEmpty else {
                throw FlexMenuFailure.message("菜单项的 id、title、action 不能为空：\(script.path)")
            }
            guard ids.insert(item.id).inserted else {
                throw FlexMenuFailure.message("重复的菜单 ID：\(item.id)")
            }
            guard FileManager.default.fileExists(
                atPath: configuration.scriptURL(for: item.action).path
            ) else {
                throw FlexMenuFailure.message("动作脚本不存在：\(item.action)")
            }
        }
    }

    static func run(
        item: MenuItemDefinition,
        configuration: MenuConfiguration,
        context: MenuContext
    ) throws -> ShellResult {
        let input = try JSONEncoder().encode(context)
        return try ShellProcess.run(
            executable: "/bin/zsh",
            arguments: [configuration.scriptURL(for: item.action).path] + context.filePaths,
            input: input,
            timeout: 60
        )
    }
}
