import AppKit
import SwiftUI

private final class FlexMenuAppDelegate: NSObject, NSApplicationDelegate {
    weak var editorModel: EditorModel?

    func applicationShouldTerminate(_: NSApplication) -> NSApplication.TerminateReply {
        if let editorModel, editorModel.hasUnsavedMenu || editorModel.hasUnsavedAction {
            let alert = NSAlert()
            alert.messageText = L10n.text("有未保存的脚本修改")
            alert.informativeText = L10n.text("退出后将丢失这些修改。")
            alert.addButton(withTitle: L10n.text("退出并丢弃"))
            alert.addButton(withTitle: L10n.text("取消"))
            guard alert.runModal() == .alertFirstButtonReturn else {
                return .terminateCancel
            }
        }
        return .terminateNow
    }
}

struct FlexMenuApp: App {
    @NSApplicationDelegateAdaptor(FlexMenuAppDelegate.self) private var appDelegate
    @State private var editorModel = EditorModel()

    var body: some Scene {
        WindowGroup {
            EditorView(model: editorModel)
                .onAppear { appDelegate.editorModel = editorModel }
        }
    }
}
