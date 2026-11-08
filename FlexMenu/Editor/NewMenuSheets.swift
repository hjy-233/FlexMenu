import SwiftUI

struct NewMenuSheet: View {
    let onCreate: (String, String) async throws -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var mode = "normal"
    @State private var errorMessage: String?
    @State private var isSaving = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L10n.text("添加菜单")).font(.title2)
            TextField(L10n.text("脚本名称（不含 .sh）"), text: $name)
            Picker(L10n.text("适用模式"), selection: $mode) {
                Text(L10n.text("普通")).tag("normal")
                Text(L10n.text("拖动文件")).tag("dragging")
            }
            if let errorMessage {
                Text(errorMessage).foregroundStyle(.red)
            }
            HStack {
                Spacer()
                Button(L10n.text("取消")) { dismiss() }
                Button(L10n.text("创建菜单")) {
                    isSaving = true
                    Task {
                        do {
                            try await onCreate(name, mode)
                            dismiss()
                        } catch {
                            errorMessage = error.localizedDescription
                            isSaving = false
                        }
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(isSaving || name.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 420)
    }
}

struct NewActionSheet: View {
    let onCreate: (String, String, String, String) async throws -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var identifier = ""
    @State private var title = ""
    @State private var name = ""
    @State private var source = ""
    @State private var errorMessage: String?
    @State private var isSaving = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.text("新建操作")).font(.title2)
            TextField(L10n.text("操作标识"), text: $identifier)
            TextField(L10n.text("显示名称"), text: $title)
            TextField(L10n.text("动作脚本名称（不含 .sh）"), text: $name)
            Text(L10n.text("动作脚本内容"))
            TextEditor(text: $source)
                .font(.system(.body, design: .monospaced))
                .frame(height: 220)
            if let errorMessage {
                Text(errorMessage).foregroundStyle(.red)
            }
            HStack {
                Spacer()
                Button(L10n.text("取消")) { dismiss() }
                Button(L10n.text("创建操作")) {
                    isSaving = true
                    Task {
                        do {
                            try await onCreate(identifier, title, name, source)
                            dismiss()
                        } catch {
                            errorMessage = error.localizedDescription
                            isSaving = false
                        }
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(isSaving || identifier.isEmpty || title.isEmpty || name.isEmpty || source.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 520)
    }
}
