import CoreFoundation
import Foundation

private struct ServiceReply: Codable {
    let error: String?
}

enum ServiceCommand: Codable {
    case showMenu
    case configuration(ConfigurationChange)
}

enum ServiceIPC {
    private static var portName: CFString {
        "org.dcstudio.FlexMenu.command.\(getuid())" as CFString
    }

    static func send(_ command: ServiceCommand) throws {
        guard let port = CFMessagePortCreateRemote(nil, portName) else {
            throw FlexMenuFailure.message(L10n.text("服务未运行，请先运行 service start"))
        }
        defer { CFMessagePortInvalidate(port) }

        let request = try JSONEncoder().encode(command)
        var response: Unmanaged<CFData>?
        let status = CFMessagePortSendRequest(
            port, 0, request as CFData, 3, 3, CFRunLoopMode.defaultMode?.rawValue, &response
        )
        guard status == kCFMessagePortSuccess, let response else {
            throw FlexMenuFailure.message(L10n.format("服务命令未得到确认（状态 %d）", status))
        }
        let reply = try JSONDecoder().decode(
            ServiceReply.self,
            from: response.takeRetainedValue() as Data
        )
        if let error = reply.error {
            throw FlexMenuFailure.message(error)
        }
    }

    static func waitUntilReady(timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            if let port = CFMessagePortCreateRemote(nil, portName) {
                CFMessagePortInvalidate(port)
                return true
            }
            Thread.sleep(forTimeInterval: 0.05)
        } while Date() < deadline
        return false
    }

    static func reply(for data: CFData?, apply: (ServiceCommand) throws -> Void) -> CFData {
        do {
            guard let data else {
                throw FlexMenuFailure.message(L10n.text("服务命令缺少数据"))
            }
            let command = try JSONDecoder().decode(ServiceCommand.self, from: data as Data)
            try apply(command)
            return try (JSONEncoder().encode(ServiceReply(error: nil))) as CFData
        } catch {
            let message = error.localizedDescription
            let encoded = (try? JSONEncoder().encode(ServiceReply(error: message)))
                ?? Data("{\"error\":\"Command failed\"}".utf8)
            return encoded as CFData
        }
    }

    static var name: CFString {
        portName
    }
}

@MainActor
final class ServiceCommandServer {
    private var port: CFMessagePort?
    private let apply: (ServiceCommand) throws -> Void

    init(apply: @escaping (ServiceCommand) throws -> Void) throws {
        self.apply = apply
        port = nil
        var context = CFMessagePortContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )
        var shouldFree = DarwinBoolean(false)
        guard let port = CFMessagePortCreateLocal(
            nil,
            ServiceIPC.name,
            { _, _, data, info in
                guard let info else { return nil }
                let server = Unmanaged<ServiceCommandServer>.fromOpaque(info).takeUnretainedValue()
                let response = MainActor.assumeIsolated {
                    ServiceIPC.reply(for: data, apply: server.apply)
                }
                return Unmanaged.passRetained(response)
            },
            &context,
            &shouldFree
        ), !shouldFree.boolValue else {
            throw FlexMenuFailure.message(L10n.text("无法启动命令服务"))
        }
        self.port = port
        CFMessagePortSetDispatchQueue(port, DispatchQueue.main)
    }

    deinit {
        if let port {
            CFMessagePortInvalidate(port)
        }
    }
}
