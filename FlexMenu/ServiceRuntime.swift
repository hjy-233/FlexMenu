import AppKit
import Foundation

@MainActor
final class ServiceRuntime {
    private let panelController: MenuPanelController
    private let shortcut = Shortcut()
    private var notificationObserver: NSObjectProtocol?

    private init(configuration: MenuConfiguration) {
        panelController = MenuPanelController(configuration: configuration)
    }

    static func run() {
        do {
            let configuration = try ConfigurationStore.loadSnapshot()
            let application = NSApplication.shared
            application.setActivationPolicy(.accessory)
            let runtime = ServiceRuntime(configuration: configuration)
            try runtime.start(configuration: configuration)
            application.run()
            withExtendedLifetime(runtime) {}
        } catch {
            FileHandle.standardError.write(Data("flexmenu: \(error.localizedDescription)\n".utf8))
            exit(EXIT_FAILURE)
        }
    }

    private func start(configuration: MenuConfiguration) throws {
        shortcut.onPress = { [weak self] in
            Task { @MainActor in self?.panelController.show() }
        }
        try shortcut.register(configuration)
        notificationObserver = DistributedNotificationCenter.default().addObserver(
            forName: .flexMenuShow,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.panelController.show() }
        }
    }

    deinit {
        if let notificationObserver {
            DistributedNotificationCenter.default().removeObserver(notificationObserver)
        }
    }
}
