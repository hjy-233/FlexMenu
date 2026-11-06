import Foundation

enum MenuScripts {
    static func resolve(
        configuration: MenuConfiguration,
        context: MenuContext
    ) throws -> [MenuItemDefinition] {
        let input = try JSONEncoder().encode(context)
        for script in configuration.menuScripts {
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
            if let mode = output.mode {
                guard ["normal", "dragging"].contains(mode) else {
                    throw FlexMenuFailure.message("菜单模式无效：\(script.path)")
                }
                guard mode == context.mode else { continue }
            }
            guard !output.items.isEmpty else { continue }
            try validate(output.items, script: script, configuration: configuration)
            return output.items
        }
        return []
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
