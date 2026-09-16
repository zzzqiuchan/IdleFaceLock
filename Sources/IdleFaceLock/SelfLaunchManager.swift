import Foundation

final class SelfLaunchManager: @unchecked Sendable {
    static let shared = SelfLaunchManager()

    private let label = "com.idlefacelock.app"

    private var launchAgentURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("LaunchAgents", isDirectory: true)
            .appendingPathComponent("\(label).plist")
    }

    private var applicationURL: URL {
        Bundle.main.bundleURL
    }

    private init() {}

    var isEnabled: Bool {
        FileManager.default.fileExists(atPath: launchAgentURL.path)
    }

    var isCurrentProcessManaged: Bool {
        let result = try? runLaunchctl(
            arguments: [
                "print",
                "gui/\\(getuid())/\\(label)"
            ]
        )

        guard let result, result.status == 0 else {
            return false
        }

        let pid = String(getpid())
        return result.output.contains("pid = \(pid)")
    }

    func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try enable()
        } else {
            try disable()
        }
    }

    private func enable() throws {
        let fm = FileManager.default

        try fm.createDirectory(
            at: launchAgentURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let plist: [String: Any] = [
            "Label": label,
            "ProgramArguments": [
                applicationURL
                    .appendingPathComponent("Contents/MacOS/IdleFaceLock")
                    .path
            ],
            "RunAtLoad": true,
            "KeepAlive": true,
            "ProcessType": "Interactive",
            "ThrottleInterval": 10,
            "LimitLoadToSessionType": "Aqua"
        ]

        let data = try PropertyListSerialization.data(
            fromPropertyList: plist,
            format: .xml,
            options: 0
        )

        try data.write(
            to: launchAgentURL,
            options: .atomic
        )

        try bootoutIfLoaded()
        try bootstrap()

        AppLogger.log(
            "Login item enabled:",
            launchAgentURL.path
        )
    }

    private func disable() throws {
        if FileManager.default.fileExists(atPath: launchAgentURL.path) {
            try FileManager.default.removeItem(at: launchAgentURL)
        }

        AppLogger.log("Login startup disabled")
    }

    private func bootstrap() throws {
        let result = try runLaunchctl(
            arguments: [
                "bootstrap",
                "gui/\(getuid())",
                launchAgentURL.path
            ]
        )

        guard result.status == 0 else {
            throw LaunchError.commandFailed(
                command: "launchctl bootstrap",
                output: result.output
            )
        }
    }

    private func bootoutIfLoaded() throws {
        let result = try runLaunchctl(
            arguments: [
                "bootout",
                "gui/\(getuid())/\(label)"
            ]
        )

        // bootout returns non-zero when the job is not loaded.
        // That is an expected state during normal enable/disable operations.
        if result.status != 0 {
            return
        }
    }

    private func runLaunchctl(
        arguments: [String]
    ) throws -> (status: Int32, output: String) {
        let process = Process()
        let outputPipe = Pipe()

        process.executableURL = URL(
            fileURLWithPath: "/bin/launchctl"
        )
        process.arguments = arguments
        process.standardOutput = outputPipe
        process.standardError = outputPipe

        try process.run()
        process.waitUntilExit()

        let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(
            data: data,
            encoding: .utf8
        ) ?? ""

        return (
            process.terminationStatus,
            output.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    enum LaunchError: LocalizedError {
        case commandFailed(command: String, output: String)

        var errorDescription: String? {
            switch self {
            case let .commandFailed(command, output):
                if output.isEmpty {
                    return "\(command) failed."
                }
                return "\(command) failed: \(output)"
            }
        }
    }
}
