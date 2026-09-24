import Foundation

enum AppConfig {
    private static let thresholdKey = "idleThreshold"

    static let defaultIdleThreshold: TimeInterval = 5 * 60
    static let idleCheckInterval: TimeInterval = 1
    static let activityThreshold: TimeInterval = 2

    static let cameraWarmupTime: TimeInterval = 0.15
    // Overall detection budget, counted from camera start and therefore
    // including warmup/first-frame latency. Observed first analyzable frame
    // arrives ~1.4-1.7s after the camera turns on, and analyzed frames are now
    // spaced out over ~1.5s (see minFrameInterval / maxDetectionFrames), so the
    // worst case is roughly 1.7s + 1.5s + Vision overhead. Budget must clear
    // that or the timeout fires before all frames are sampled. When a person is
    // present the check still ends as soon as requiredFaceFrames are seen, so
    // this larger budget only affects the worst case (nobody / camera slow to
    // stream).
    static let maxDetectionDuration: TimeInterval = 4.0
    // Number of frames actually analyzed (the first delivered frame is skipped
    // as warmup, so total delivered frames = maxDetectionFrames + 1). At the
    // ~71ms/frame cadence set by minFrameInterval this spreads the "no person"
    // scan over ~1.5s of real coverage.
    static let maxDetectionFrames = 22
    static let requiredFaceFrames = 2

    // Minimum spacing applied after a frame that found no qualifying face. The
    // camera streams at ~30fps (~33ms/frame), so without throttling the frames
    // arrive as a burst within ~150ms — near-duplicate frames from a single
    // instant. Throttling is decided per frame: after a miss, wait this long
    // before the next analysis; after a hit, analyze the next frame immediately
    // to confirm presence fast. The net effect is that a "no person" scan
    // stretches over ~1.5s (real temporal coverage — catches a head turned
    // away, a blink, or a transient miss for that long) while a present person
    // is confirmed back-to-back with no added delay.
    static let minFrameInterval: TimeInterval = 0.06

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