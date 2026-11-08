import SwiftUI

struct ShortcutSettingsView: View {
    @Bindable var model: EditorModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(L10n.text("快捷键")).font(.title2)
            TextField(L10n.text("键（space 或 a–z）"), text: $model.shortcutKey)
            HStack {
                Toggle("⌘ Command", isOn: modifierBinding("command"))
                Toggle("⌥ Option", isOn: modifierBinding("option"))
                Toggle("⌃ Control", isOn: modifierBinding("control"))
                Toggle("⇧ Shift", isOn: modifierBinding("shift"))
            }
            .toggleStyle(.checkbox)
            HStack {
                Spacer()
                Button(L10n.text("关闭")) { dismiss() }
                Button(L10n.text("保存快捷键")) { model.saveShortcut() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(model.isBusy)
            }
        }
        .padding(24)
        .frame(width: 510)
    }

    private func modifierBinding(_ name: String) -> Binding<Bool> {
        Binding(
            get: { model.shortcutModifiers.contains(name) },
            set: { enabled in
                if enabled {
                    model.shortcutModifiers.insert(name)
                } else {
                    model.shortcutModifiers.remove(name)
                }
            }
        )
    }
}
