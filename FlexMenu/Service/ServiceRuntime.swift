import AppKit
import Foundation

@MainActor
final class ServiceRuntime {
    private let panelController: MenuPanelController
    private let shortcut = Shortcut()
    private var configuration: MenuConfiguration
    private var commandServer: ServiceCommandServer?

    private init(configuration: MenuConfiguration) {
        self.configuration = configuration
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
        commandServer = try ServiceCommandServer { [weak self] command in
            guard let self else {
                throw FlexMenuFailure.message(L10n.text("服务已停止"))
            }
            switch command {
            case .showMenu:
                self.panelController.show()
            case let .configuration(change):
                try self.apply(change)
            }
        }
    }

    private func apply(_ change: ConfigurationChange) throws {
        var updated = configuration
        try change.apply(to: &updated)
        try Shortcut.validate(updated)
        let shortcutChanged = updated.shortcutKey != configuration.shortcutKey ||
            updated.shortcutModifiers != configuration.shortcutModifiers
        if shortcutChanged {
            shortcut.unregister()
            do {
                try shortcut.register(updated)
            } catch {
                try? shortcut.register(configuration)
                throw error
            }
        }
        do {
            try ConfigurationStore.save(updated)
        } catch {
            if shortcutChanged {
                shortcut.unregister()
                try? shortcut.register(configuration)
            }
            throw error
        }
        configuration = updated
        panelController.updateConfiguration(updated)
    }
}
