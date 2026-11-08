import AppKit
import SwiftUI

private final class FlexMenuAppDelegate: NSObject, NSApplicationDelegate {
    weak var editorModel: EditorModel?

    func applicationShouldTerminate(_: NSApplication) -> NSApplication.TerminateReply {
        if let editorModel, editorModel.hasUnsavedMenu || editorModel.hasUnsavedAction {
            let alert = NSAlert()
            alert.messageText = "有未保存的脚本修改"
            alert.informativeText = "退出后将丢失这些修改。"
            alert.addButton(withTitle: "退出并丢弃")
            alert.addButton(withTitle: "取消")
            guard alert.runModal() == .alertFirstButtonReturn else {
                return .terminateCancel
            }
        }
        Task.detached {
            do {
                try ServiceControl.stopIfNeeded()
                await MainActor.run {
                    NSApp.reply(toApplicationShouldTerminate: true)
                }
            } catch {
                await MainActor.run {
                    let alert = NSAlert()
                    alert.messageText = "无法停止 FlexMenu 服务"
                    alert.informativeText = error.localizedDescription
                    alert.runModal()
                    NSApp.reply(toApplicationShouldTerminate: false)
                }
            }
        }
        return .terminateLater
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
