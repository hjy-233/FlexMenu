import SwiftUI

struct EditorView: View {
    @Bindable var model: EditorModel
    @State private var showsShortcutSheet = false
    @State private var showsNewMenuSheet = false
    @State private var showsNewActionSheet = false
    @State private var selectedTab: EditorTab = .preview

    private enum EditorTab: Hashable {
        case preview
        case visual
        case source
    }

    var body: some View {
        @Bindable var model = model

        NavigationSplitView {
            List(selection: Binding(
                get: { model.selectedScript?.path },
                set: { path in
                    guard let script = model.configuration?.menuScripts.first(where: {
                        $0.path == path
                    }) else { return }
                    model.selectScript(script)
                }
            )) {
                Section(L10n.text("菜单脚本")) {
                    ForEach(model.configuration?.menuScripts ?? [], id: \.path) { script in
                        Label(
                            URL(fileURLWithPath: script.path).lastPathComponent,
                            systemImage: "circle.hexagongrid"
                        )
                        .tag(script.path)
                    }
                }
            }
            .navigationTitle("FlexMenu")
        } detail: {
            if let script = model.selectedScript {
                menuEditor(script: script, model: model)
            } else {
                ContentUnavailableView(L10n.text("没有菜单脚本"), systemImage: "circle.hexagongrid")
            }
        }
        .frame(minWidth: 850, minHeight: 600)
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                Button {
                    showsNewMenuSheet = true
                } label: {
                    Label(L10n.text("添加菜单"), systemImage: "plus.rectangle.on.folder")
                }
                .disabled(model.isBusy || !model.serviceRunning)

                Button {
                    model.toggleService()
                } label: {
                    Label(
                        model.serviceRunning ? L10n.text("停止服务") : L10n.text("启动服务"),
                        systemImage: model.serviceRunning ? "stop.circle" : "play.circle"
                    )
                }
                .disabled(model.isBusy)

                Button {
                    model.reloadConfiguration()
                } label: {
                    Label(L10n.text("重新加载配置"), systemImage: "arrow.clockwise")
                }
                .disabled(model.isBusy)

                Button {
                    showsShortcutSheet = true
                } label: {
                    Label(L10n.text("快捷键"), systemImage: "keyboard")
                }
            }

            ToolbarItemGroup(placement: .primaryAction) {
                if model.selectedScript != nil {
                    Button {
                        model.refreshPreview()
                    } label: {
                        Label(L10n.text("刷新当前菜单"), systemImage: "arrow.triangle.2.circlepath")
                    }
                    .disabled(model.isBusy)

                    if selectedTab == .visual, model.visualTemplate != nil {
                        Menu {
                            Button(L10n.text("添加已有动作")) { model.addVisualItem() }
                            Button(L10n.text("新建动作脚本…")) { showsNewActionSheet = true }
                        } label: {
                            Label(L10n.text("添加操作"), systemImage: "plus")
                        }
                        .disabled(model.isBusy)

                        Button {
                            model.saveVisualMenu()
                        } label: {
                            Label(L10n.text("保存菜单"), systemImage: "square.and.arrow.down")
                        }
                        .disabled(model.isBusy || !model.hasUnsavedVisual)
                    } else if selectedTab == .source {
                        Button {
                            model.saveMenu()
                        } label: {
                            Label(L10n.text("保存菜单脚本"), systemImage: "square.and.arrow.down")
                        }
                        .disabled(model.isBusy || !model.hasUnsavedSource)
                    } else if model.selectedItem != nil {
                        Button {
                            model.saveAction()
                        } label: {
                            Label(L10n.text("保存动作脚本"), systemImage: "square.and.arrow.down")
                        }
                        .disabled(model.isBusy || !model.hasUnsavedAction)
                    }
                }
            }
        }
        .sheet(isPresented: $showsShortcutSheet) {
            ShortcutSettingsView(model: model)
        }
        .sheet(isPresented: $showsNewMenuSheet) {
            NewMenuSheet { name, mode in
                try await model.createMenu(name: name, mode: mode)
            }
        }
        .sheet(isPresented: $showsNewActionSheet) {
            NewActionSheet { identifier, title, name, source in
                try await model.createAction(
                    id: identifier,
                    title: title,
                    name: name,
                    source: source
                )
            }
        }
        .task { model.start() }
        .alert("FlexMenu", isPresented: Binding(
            get: { model.message != nil },
            set: {
                if !$0 {
                    model.message = nil
                }
            }
        )) {
            Button(L10n.text("好")) { model.message = nil }
        } message: {
            Text(model.message ?? "")
        }
    }

    private func menuEditor(script: MenuScript, model: EditorModel) -> some View {
        @Bindable var model = model
        return VStack(spacing: 0) {
            HStack {
                Text(script.path).font(.headline)
            }
            .padding()

            Picker(L10n.text("页面"), selection: $selectedTab) {
                Text(L10n.text("预览与动作")).tag(EditorTab.preview)
                Text(L10n.text("可视化编辑")).tag(EditorTab.visual)
                Text(L10n.text("源码")).tag(EditorTab.source)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 370)
            .padding(.bottom, 8)

            Group {
                if selectedTab == .preview {
                    previewEditor(model: model)
                } else if selectedTab == .visual {
                    visualEditor(model: model)
                } else {
                    VStack(alignment: .leading) {
                        Text(L10n.text("菜单脚本返回 JSON，保存前会检查两种上下文的输出。"))
                            .foregroundStyle(.secondary)
                        TextEditor(text: $model.menuText)
                            .font(.system(.body, design: .monospaced))
                    }
                    .padding()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}

private extension EditorView {
    private func visualEditor(model: EditorModel) -> some View {
        @Bindable var model = model
        return Group {
            if model.visualTemplate != nil {
                VStack(alignment: .leading, spacing: 12) {
                    Picker(L10n.text("适用模式"), selection: $model.visualMode) {
                        Text(L10n.text("普通")).tag("normal")
                        Text(L10n.text("拖动文件")).tag("dragging")
                        Text(L10n.text("不限")).tag("any")
                    }
                    .frame(width: 260)
                    List {
                        ForEach($model.visualItems) { $item in
                            HStack {
                                TextField(L10n.text("标识"), text: $item.id)
                                    .frame(minWidth: 100)
                                TextField(L10n.text("名称"), text: $item.title)
                                    .frame(minWidth: 130)
                                TextField(L10n.text("动作脚本路径"), text: $item.action)
                                    .frame(minWidth: 180)
                                Button {
                                    model.removeVisualItem(item.identity)
                                } label: {
                                    Image(systemName: "minus.circle")
                                }
                                .buttonStyle(.borderless)
                                .help(L10n.text("删除这个操作"))
                            }
                        }
                    }
                }
                .padding()
            } else {
                ContentUnavailableView(
                    L10n.text("此脚本包含 Shell 逻辑"),
                    systemImage: "curlybraces",
                    description: Text(L10n.text("请在“源码”页编辑；可视化保存不会覆盖动态脚本。"))
                )
            }
        }
    }

    private func previewEditor(model: EditorModel) -> some View {
        @Bindable var model = model
        return HStack(alignment: .top, spacing: 0) {
            VStack(alignment: .leading) {
                Text(model.previewMode).font(.headline)
                ContentView(model: model.previewModel)
                    .frame(height: 220)
                    .frame(maxWidth: .infinity)
                List(model.previewItems, id: \.id) { item in
                    Button {
                        model.selectItem(item)
                    } label: {
                        VStack(alignment: .leading) {
                            Text(item.title)
                            Text(item.id).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            Divider()

            if let item = model.selectedItem {
                VStack(alignment: .leading) {
                    Text(item.title).font(.title2)
                    Text(L10n.format("动作脚本：%@", item.action))
                        .foregroundStyle(.secondary)
                    TextEditor(text: $model.actionText)
                        .font(.system(.body, design: .monospaced))
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                ContentUnavailableView(L10n.text("选择一个操作查看详情"), systemImage: "cursorarrow.click")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding()
    }
}
