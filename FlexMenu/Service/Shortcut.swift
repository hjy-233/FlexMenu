import Carbon
import Foundation

final class Shortcut {
    private var hotKey: EventHotKeyRef?
    private var handler: EventHandlerRef?
    var onPress: (() -> Void)?

    static func validate(_ configuration: MenuConfiguration) throws {
        guard let key = configuration.shortcutKey,
              keyCodes[key.lowercased()] != nil
        else {
            throw FlexMenuFailure.message("快捷键未配置或键名不支持")
        }
        guard !configuration.shortcutModifiers.isEmpty,
              configuration.shortcutModifiers.allSatisfy({ modifiers[$0] != nil })
        else {
            throw FlexMenuFailure.message("快捷键修饰键无效")
        }
    }

    func register(_ configuration: MenuConfiguration) throws {
        try Self.validate(configuration)
        guard let key = configuration.shortcutKey,
              let code = Self.keyCodes[key.lowercased()] else { return }
        let flags = configuration.shortcutModifiers.reduce(UInt32(0)) {
            $0 | (Self.modifiers[$1] ?? 0)
        }
        let identifier = EventHotKeyID(signature: 0x464D_4E55, id: 1)
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let pointer = Unmanaged.passUnretained(self).toOpaque()
        let installStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, userData in
                guard let userData else { return noErr }
                let shortcut = Unmanaged<Shortcut>.fromOpaque(userData)
                    .takeUnretainedValue()
                shortcut.onPress?()
                return noErr
            },
            1,
            &eventType,
            pointer,
            &handler
        )
        guard installStatus == noErr else {
            throw FlexMenuFailure.message("无法安装快捷键事件：\(installStatus)")
        }
        let registerStatus = RegisterEventHotKey(
            code,
            flags,
            identifier,
            GetApplicationEventTarget(),
            0,
            &hotKey
        )
        guard registerStatus == noErr else {
            if let handler {
                RemoveEventHandler(handler)
                self.handler = nil
            }
            throw FlexMenuFailure.message("快捷键注册失败：\(registerStatus)")
        }
    }

    func unregister() {
        if let hotKey {
            UnregisterEventHotKey(hotKey)
            self.hotKey = nil
        }
        if let handler {
            RemoveEventHandler(handler)
            self.handler = nil
        }
    }

    deinit { unregister() }

    private static let modifiers: [String: UInt32] = [
        "command": UInt32(cmdKey),
        "option": UInt32(optionKey),
        "control": UInt32(controlKey),
        "shift": UInt32(shiftKey)
    ]

    private static let keyCodes: [String: UInt32] = [
        "space": UInt32(kVK_Space),
        "a": UInt32(kVK_ANSI_A), "b": UInt32(kVK_ANSI_B),
        "c": UInt32(kVK_ANSI_C), "d": UInt32(kVK_ANSI_D),
        "e": UInt32(kVK_ANSI_E), "f": UInt32(kVK_ANSI_F),
        "g": UInt32(kVK_ANSI_G), "h": UInt32(kVK_ANSI_H),
        "i": UInt32(kVK_ANSI_I), "j": UInt32(kVK_ANSI_J),
        "k": UInt32(kVK_ANSI_K), "l": UInt32(kVK_ANSI_L),
        "m": UInt32(kVK_ANSI_M), "n": UInt32(kVK_ANSI_N),
        "o": UInt32(kVK_ANSI_O), "p": UInt32(kVK_ANSI_P),
        "q": UInt32(kVK_ANSI_Q), "r": UInt32(kVK_ANSI_R),
        "s": UInt32(kVK_ANSI_S), "t": UInt32(kVK_ANSI_T),
        "u": UInt32(kVK_ANSI_U), "v": UInt32(kVK_ANSI_V),
        "w": UInt32(kVK_ANSI_W), "x": UInt32(kVK_ANSI_X),
        "y": UInt32(kVK_ANSI_Y), "z": UInt32(kVK_ANSI_Z)
    ]
}
