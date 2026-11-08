import Foundation
import Observation

@MainActor
@Observable
final class EditorModel {
    var configuration: MenuConfiguration?
    var selectedScript: MenuScript?
    var selectedItem: MenuItemDefinition?
    var menuText = ""
    var actionText = ""
    var previewItems: [MenuItemDefinition] = []
    var previewMode = ""
    var previewModel = MenuModel()
    var visualTemplate: VisualMenuScript?
    var visualItems: [EditableMenuItem] = []
    var visualMode = "normal"
    var shortcutKey = "space"
    var shortcutModifiers: Set<String> = []
    var serviceRunning = false
    var message: String?
    var isBusy = false
    var started = false
    private var previewRequest = 0
    private var originalMenuText = ""
    private var originalActionText = ""
    private var originalVisualItems: [EditableMenuItem] = []
    private var originalVisualMode = "normal"

    var hasUnsavedMenu: Bool {
        hasUnsavedSource || hasUnsavedVisual
    }

    var hasUnsavedSource: Bool {
        menuText != originalMenuText
    }

    var hasUnsavedVisual: Bool {
        visualItems != originalVisualItems || visualMode != originalVisualMode
    }

    var hasUnsavedAction: Bool {
        actionText != originalActionText
    }

    func selectScript(_ script: MenuScript) {
        guard let configuration else { return }
        guard !hasUnsavedMenu, !hasUnsavedAction else {
            message = "请先保存当前脚本，再切换菜单"
            return
        }
        do {
            menuText = try String(
                contentsOf: configuration.scriptURL(for: script.path),
                encoding: .utf8
            )
            selectedScript = script
            originalMenuText = menuText
            loadVisual()
            selectedItem = nil
            actionText = ""
            originalActionText = ""
            loadPreview()
        } catch {
            report(error)
        }
    }

    func selectItem(_ item: MenuItemDefinition) {
        guard let configuration else { return }
        guard !hasUnsavedAction else {
            message = "请先保存当前动作脚本"
            return
        }
        do {
            actionText = try String(
                contentsOf: configuration.scriptURL(for: item.action),
                encoding: .utf8
            )
            selectedItem = item
            originalActionText = actionText
            previewModel.selectedIndex = previewItems.firstIndex { $0.id == item.id } ?? -1
        } catch {
            report(error)
        }
    }

    func saveMenu() {
        guard !isBusy, let script = selectedScript, let configuration else { return }
        guard !hasUnsavedVisual else {
            message = "请先保存可视化菜单修改"
            return
        }
        guard !hasUnsavedAction else {
            message = "请先保存当前动作脚本"
            return
        }
        let text = menuText
        isBusy = true
        Task.detached { [weak self] in
            do {
                try EditorFiles.saveMenu(text, script: script, configuration: configuration)
                await self?.menuSaved()
            } catch {
                await self?.report(error)
            }
        }
    }

    func saveAction() {
        guard !isBusy, let item = selectedItem, let configuration else { return }
        let text = actionText
        isBusy = true
        Task.detached { [weak self] in
            do {
                try EditorFiles.saveAction(text, path: item.action, configuration: configuration)
                await self?.actionSaved()
            } catch {
                await self?.report(error)
            }
        }
    }

    func saveShortcut() {
        guard !isBusy else { return }
        let key = shortcutKey
        let modifiers = ["command", "option", "control", "shift"]
            .filter { shortcutModifiers.contains($0) }
        isBusy = true
        Task.detached { [weak self] in
            do {
                try EditorFiles.saveShortcut(key: key, modifiers: modifiers)
                let configuration = try ConfigurationStore.loadSnapshot()
                await self?.shortcutSaved(configuration)
            } catch {
                await self?.report(error)
            }
        }
    }

    func refreshPreview() {
        guard !hasUnsavedMenu, !hasUnsavedAction else {
            message = "请先保存脚本，再刷新预览"
            return
        }
        loadPreview()
    }

    func load(_ configuration: MenuConfiguration, running: Bool) {
        self.configuration = configuration
        serviceRunning = running
        shortcutKey = configuration.shortcutKey ?? "space"
        shortcutModifiers = Set(configuration.shortcutModifiers)
        isBusy = false
        let selectedScriptExists = selectedScript.map { script in
            configuration.menuScripts.contains { $0.path == script.path }
        } ?? false
        if let selectedScript, selectedScriptExists {
            selectScript(selectedScript)
        } else if let first = configuration.menuScripts.first {
            selectScript(first)
        }
    }

    private func loadPreview() {
        guard let configuration, let script = selectedScript else { return }
        previewRequest += 1
        let request = previewRequest
        previewItems = []
        previewMode = "正在读取菜单…"
        previewModel.menuItems = []
        previewModel.selectedIndex = -1
        Task.detached { [weak self] in
            do {
                let normal = try MenuScripts.preview(
                    script: script,
                    configuration: configuration,
                    context: .normal()
                )
                let output: MenuOutput
                let mode: String
                if normal.mode == "normal", !normal.items.isEmpty {
                    output = normal
                    mode = "普通菜单"
                } else {
                    let dragging = try MenuScripts.preview(
                        script: script,
                        configuration: configuration,
                        context: EditorFiles.sampleFileContext()
                    )
                    output = dragging.mode == "dragging" ? dragging : normal
                    mode = output.mode == "dragging"
                        ? "文件拖动菜单（示例文件）" : "普通菜单"
                }
                await self?.finishPreview(output.items, mode: mode, request: request)
            } catch {
                await self?.previewFailed(error, request: request)
            }
        }
    }

    private func finishPreview(_ items: [MenuItemDefinition], mode: String, request: Int) {
        guard previewRequest == request else { return }
        previewItems = items
        previewMode = mode
        previewModel.menuItems = items.map { MenuItem(id: $0.id, title: $0.title) }
        previewModel.state = .normal
        selectedItem = nil
        actionText = ""
        originalActionText = ""
    }

    private func previewFailed(_ error: Error, request: Int) {
        guard previewRequest == request else { return }
        previewMode = "无法预览"
        report(error)
    }

    private func menuSaved() {
        isBusy = false
        originalMenuText = menuText
        message = "菜单脚本已保存"
        loadPreview()
    }

    private func actionSaved() {
        originalActionText = actionText
        saved("动作脚本已保存")
    }

    private func shortcutSaved(_ configuration: MenuConfiguration) {
        self.configuration = configuration
        saved("快捷键已保存并生效")
    }

    private func saved(_ text: String) {
        isBusy = false
        message = text
    }

    func report(_ error: Error) {
        isBusy = false
        message = error.localizedDescription
    }
}

@MainActor
extension EditorModel {
    func createMenu(name: String, mode: String) async throws {
        guard !isBusy, serviceRunning else {
            throw FlexMenuFailure.message("请先启动服务")
        }
        guard !hasUnsavedMenu, !hasUnsavedAction else {
            throw FlexMenuFailure.message("请先保存当前脚本")
        }
        isBusy = true
        defer { isBusy = false }
        let script = try await Task.detached {
            try EditorFiles.createMenu(name: name, mode: mode)
        }.value
        let configuration = try ConfigurationStore.loadSnapshot()
        load(configuration, running: true)
        selectScript(script)
    }

    func createAction(id: String, title: String, name: String, source: String) async throws {
        guard !isBusy,
              let script = selectedScript,
              let template = visualTemplate,
              let configuration
        else { throw FlexMenuFailure.message("当前菜单无法可视化添加操作") }
        guard !hasUnsavedMenu, !hasUnsavedAction else {
            throw FlexMenuFailure.message("请先保存当前脚本")
        }
        let mode = visualMode
        let items = visualItems
        let request = EditorFiles.ActionCreation(
            id: id,
            title: title,
            name: name,
            source: source,
            script: script,
            template: template,
            mode: mode,
            items: items,
            configuration: configuration
        )
        isBusy = true
        defer { isBusy = false }
        let menuSource = try await Task.detached {
            try EditorFiles.createAction(request)
        }.value
        menuText = menuSource
        originalMenuText = menuSource
        loadVisual()
        loadPreview()
    }

    func addVisualItem() {
        guard visualTemplate != nil else { return }
        visualItems.append(EditableMenuItem())
    }

    func removeVisualItem(_ identity: UUID) {
        visualItems.removeAll { $0.identity == identity }
    }

    func saveVisualMenu() {
        guard !isBusy,
              let script = selectedScript,
              let configuration,
              let visualTemplate
        else { return }
        guard !hasUnsavedSource else {
            message = "请先保存源码修改"
            return
        }
        let items = visualItems
        let mode = visualMode
        isBusy = true
        Task.detached { [weak self] in
            do {
                let source = try visualTemplate.render(mode: mode, items: items)
                try EditorFiles.saveMenu(source, script: script, configuration: configuration)
                await self?.visualMenuSaved(source)
            } catch {
                await self?.report(error)
            }
        }
    }

    private func loadVisual() {
        visualTemplate = VisualMenuScript.parse(menuText)
        visualItems = visualTemplate?.output.items.map(EditableMenuItem.init) ?? []
        visualMode = visualTemplate?.output.mode ?? "any"
        originalVisualItems = visualItems
        originalVisualMode = visualMode
    }

    private func visualMenuSaved(_ source: String) {
        menuText = source
        originalMenuText = source
        loadVisual()
        menuSaved()
    }
}
