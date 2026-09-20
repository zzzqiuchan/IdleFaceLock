import Foundation

enum AppConfig {
    private static let thresholdKey = "idleThreshold"

    static let defaultIdleThreshold: TimeInterval = 5 * 60
    static let idleCheckInterval: TimeInterval = 1
    static let activityThreshold: TimeInterval = 2

    static let cameraWarmupTime: TimeInterval = 0.15
    static let maxDetectionDuration: TimeInterval = 1.2
    static let maxDetectionFrames = 8
    static let requiredFaceFrames = 2

    // Minimum share of the frame a face must occupy to count as "sitting at
    // the machine". Calibrated on my real hardware: sitting ~8%, leaning back
    // ~3% (both present), standing behind a pulled-out chair ~1% (absent).
    // 2% sits comfortably between leaning-back and standing.
    static let minFaceAreaRatio: CGFloat = 0.02

    static let cameraFailureCooldown: TimeInterval = 5 * 60
    static let recoverOnUserActivity = true

    static let availableIdleThresholds: [TimeInterval] = [
        1 * 60,
        3 * 60,
        5 * 60,
        10 * 60,
        15 * 60,
        20 * 60,
        30 * 60,
        45 * 60,
        60 * 60
    ]

    static var idleThreshold: TimeInterval {
        get {
            let value = UserDefaults.standard.double(forKey: thresholdKey)
            return value > 0 ? value : defaultIdleThreshold
        }
        set {
            UserDefaults.standard.set(newValue, forKey: thresholdKey)
        }
    }
}