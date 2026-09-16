import Foundation
import OSLog

enum AppLogger {
    private static let logger = Logger(
        subsystem: "com.idlefacelock.app",
        category: "main"
    )

    private static let fileQueue = DispatchQueue(
        label: "IdleFaceLock.Logger"
    )

    private static let logDirectoryURL: URL = {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Logs", isDirectory: true)
            .appendingPathComponent("IdleFaceLock", isDirectory: true)
    }()

    private static let logURL: URL = {
        logDirectoryURL.appendingPathComponent("current.log")
    }()

    private static let maxLogFileSize: UInt64 = 5 * 1024 * 1024
    private static let maxRotatedFiles = 3

    static func log(_ items: Any...) {
        write(level: .info, items: items)
    }

    static func error(_ items: Any...) {
        write(level: .error, items: items)
    }

    private enum Level {
        case info
        case error
    }

    private static func write(
        level: Level,
        items: [Any]
    ) {
        let message = items
            .map(String.init(describing:))
            .joined(separator: " ")

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"

        let line = "[\(formatter.string(from: Date()))] \(message)\n"

        print(line, terminator: "")

        switch level {
        case .info:
            logger.info("\(line, privacy: .public)")
        case .error:
            logger.error("\(line, privacy: .public)")
        }

        fileQueue.async {
            appendToFile(line)
        }
    }

    private static func appendToFile(_ line: String) {
        do {
            try FileManager.default.createDirectory(
                at: logDirectoryURL,
                withIntermediateDirectories: true
            )

            rotateIfNeeded()

            if !FileManager.default.fileExists(atPath: logURL.path) {
                try line.write(
                    to: logURL,
                    atomically: true,
                    encoding: .utf8
                )
                return
            }

            let handle = try FileHandle(forWritingTo: logURL)
            defer {
                try? handle.close()
            }

            try handle.seekToEnd()
            if let data = line.data(using: .utf8) {
                try handle.write(contentsOf: data)
            }
        } catch {
            // Logging must never affect application behavior.
        }
    }

    private static func rotateIfNeeded() {
        guard
            let attributes = try? FileManager.default.attributesOfItem(
                atPath: logURL.path
            ),
            let size = attributes[.size] as? NSNumber,
            size.uint64Value >= maxLogFileSize
        else {
            return
        }

        let fm = FileManager.default

        for index in stride(from: maxRotatedFiles - 1, through: 1, by: -1) {
            let source = logDirectoryURL
                .appendingPathComponent("current.log.\(index)")
            let destination = logDirectoryURL
                .appendingPathComponent("current.log.\(index + 1)")

            if fm.fileExists(atPath: destination.path) {
                try? fm.removeItem(at: destination)
            }

            if fm.fileExists(atPath: source.path) {
                try? fm.moveItem(at: source, to: destination)
            }
        }

        let first = logDirectoryURL
            .appendingPathComponent("current.log.1")

        if fm.fileExists(atPath: first.path) {
            try? fm.removeItem(at: first)
        }

        try? fm.moveItem(at: logURL, to: first)
    }
}
