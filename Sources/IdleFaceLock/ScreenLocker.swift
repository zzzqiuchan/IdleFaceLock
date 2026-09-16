import Foundation

final class ScreenLocker: @unchecked Sendable {
    func lock() {
        AppLogger.log("Requesting display sleep...")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        process.arguments = ["displaysleepnow"]

        do {
            try process.run()
            process.waitUntilExit()

            if process.terminationStatus == 0 {
                AppLogger.log("Display sleep requested.")
            } else {
                AppLogger.error("pmset failed:", process.terminationStatus)
            }
        } catch {
            AppLogger.error("Failed to execute pmset:", error)
        }
    }
}
