import Darwin
import Foundation

struct ShellResult {
    let status: Int32
    let output: String
    let error: String
}

enum ShellProcess {
    static func run(
        executable: String,
        arguments: [String],
        environment: [String: String] = [:],
        input: Data?,
        timeout: TimeInterval
    ) throws -> ShellResult {
        let inputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let errorURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try (input ?? Data()).write(to: inputURL, options: .atomic)
        FileManager.default.createFile(atPath: outputURL.path, contents: nil)
        FileManager.default.createFile(atPath: errorURL.path, contents: nil)
        defer {
            try? FileManager.default.removeItem(at: inputURL)
            try? FileManager.default.removeItem(at: outputURL)
            try? FileManager.default.removeItem(at: errorURL)
        }

        let inputHandle = try FileHandle(forReadingFrom: inputURL)
        let outputHandle = try FileHandle(forWritingTo: outputURL)
        let errorHandle = try FileHandle(forWritingTo: errorURL)
        defer {
            try? inputHandle.close()
            try? outputHandle.close()
            try? errorHandle.close()
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.environment = ProcessInfo.processInfo.environment.merging(environment) { _, new in new }
        process.standardOutput = outputHandle
        process.standardError = errorHandle
        process.standardInput = inputHandle

        try process.run()
        let timer = DispatchSource.makeTimerSource(queue: .global())
        timer.schedule(deadline: .now() + timeout)
        timer.setEventHandler {
            if process.isRunning {
                kill(process.processIdentifier, SIGKILL)
            }
        }
        timer.resume()
        process.waitUntilExit()
        timer.cancel()

        guard let output = try String(bytes: Data(contentsOf: outputURL), encoding: .utf8),
              let error = try String(bytes: Data(contentsOf: errorURL), encoding: .utf8)
        else {
            throw FlexMenuFailure.message("脚本输出不是 UTF-8")
        }
        return ShellResult(status: process.terminationStatus, output: output, error: error)
    }
}
