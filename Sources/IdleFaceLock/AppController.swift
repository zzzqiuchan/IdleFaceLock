import Foundation

final class AppController: @unchecked Sendable {
    private let idleDetector = IdleDetector()
    private let cameraDetector = CameraPresenceDetector()
    private let powerAssertion = PowerAssertion()
    private let powerAssertionMonitor = PowerAssertionMonitor()
    private let screenLocker = ScreenLocker()

    private let controllerQueue = DispatchQueue(
        label: "IdleFaceLock.Controller"
    )

    private var timer: DispatchSourceTimer?
    private var checkingCamera = false
    private var enabled = true
    private var waitingForUnlock = false
    private var safeMode = false
    private var safeModeUntil: Date?
    private var logicalLastActivity = Date()
    private var externalAssertionPaused = false
    private var sleeping = false
    private var cameraPermissionPrepared = false
    private var screenLocked = false

    func start() {
        controllerQueue.async { [weak self] in
            self?.startInternal()
        }
    }

    func stop() {
        controllerQueue.async { [weak self] in
            self?.stopInternal()
        }
    }

    var isEnabled: Bool {
        controllerQueue.sync { enabled }
    }

    func currentIdleThreshold() -> TimeInterval {
        controllerQueue.sync { AppConfig.idleThreshold }
    }

    func setIdleThreshold(
        _ seconds: TimeInterval,
        completion: (@Sendable () -> Void)? = nil
    ) {
        controllerQueue.async {
            AppConfig.idleThreshold = seconds
            self.logicalLastActivity = Date()
            self.externalAssertionPaused = false

            AppLogger.log(
                "Idle threshold changed:",
                "\(Int(seconds)) seconds"
            )

            completion?()
        }
    }

    func toggleEnabled(
        completion: (@Sendable () -> Void)? = nil
    ) {
        controllerQueue.async {
            self.enabled.toggle()

            if self.enabled {
                AppLogger.log("IdleFaceLock enabled.")

                self.safeMode = false
                self.safeModeUntil = nil
                self.waitingForUnlock = false
                self.externalAssertionPaused = false
                self.logicalLastActivity = Date()

                if !self.sleeping && !self.powerAssertion.isActive {
                    if !self.powerAssertion.acquire() {
                        self.enterSafeMode(
                            reason: "Unable to acquire power assertion"
                        )
                    }
                }
            } else {
                AppLogger.log("IdleFaceLock disabled.")

                self.waitingForUnlock = false
                self.externalAssertionPaused = false
                self.powerAssertion.release()
            }

            completion?()
        }
    }

    func checkNow() {
        controllerQueue.async {
            guard self.enabled else {
                AppLogger.log("Manual check ignored: disabled.")
                return
            }

            guard !self.checkingCamera else {
                AppLogger.log(
                    "Manual check ignored: camera check already running."
                )
                return
            }

            guard !self.waitingForUnlock else {
                AppLogger.log(
                    "Manual check ignored: waiting for unlock."
                )
                return
            }

            guard !self.sleeping else {
                AppLogger.log(
                    "Manual check ignored: system is sleeping."
                )
                return
            }

            guard !self.externalAssertionPaused else {
                AppLogger.log(
                    "Manual check ignored: external display assertion is active."
                )
                return
            }

            AppLogger.log("Manual presence check requested.")
            self.startPresenceCheck()
        }
    }

    func handleWillSleep() {
        controllerQueue.async {
            guard !self.sleeping else {
                return
            }

            self.sleeping = true
            self.checkingCamera = false
            self.externalAssertionPaused = false
            self.powerAssertion.release()

            AppLogger.log(
                "System sleep detected. Monitoring paused."
            )
        }
    }

    func handleDidWake() {
        controllerQueue.async {
            guard self.sleeping else {
                return
            }

            self.sleeping = false
            self.logicalLastActivity = Date()
            self.waitingForUnlock = false
            self.externalAssertionPaused = false
            self.checkingCamera = false

            AppLogger.log(
                "System wake detected. Monitoring resumed."
            )

            guard self.enabled else {
                return
            }

            if !self.powerAssertion.isActive &&
                !self.powerAssertion.acquire() {
                self.enterSafeMode(
                    reason:
                        "Unable to reacquire power assertion after wake"
                )
            }
        }
    }

    func handleScreenLocked() {
        controllerQueue.async {
            guard !self.screenLocked else {
                return
            }

            self.screenLocked = true
            self.checkingCamera = false

            // Once the session is locked, stop preventing display sleep.
            // The system should now handle display sleep according to its
            // own Lock Screen / Energy settings.
            self.powerAssertion.release()

            AppLogger.log("Screen locked. Monitoring paused.")
        }
    }

    func handleScreenUnlocked() {
        controllerQueue.async {
            guard self.screenLocked else {
                return
            }

            self.screenLocked = false
            self.checkingCamera = false
            self.waitingForUnlock = false
            self.logicalLastActivity = Date()
            self.externalAssertionPaused = false

            AppLogger.log("Screen unlocked. Monitoring resumed.")

            guard self.enabled, !self.sleeping else {
                return
            }

            if !self.powerAssertion.isActive {
                if !self.powerAssertion.acquire() {
                    self.enterSafeMode(
                        reason: "Unable to reacquire power assertion after screen unlock"
                    )
                }
            }
        }
    }

    private func startInternal() {
        guard timer == nil else {
            return
        }

        AppLogger.log("Controller started.")

        // Request/check camera permission exactly once during application startup.
        cameraDetector.prepareCameraAccess { [weak self] granted in
            self?.controllerQueue.async { [weak self] in
                guard let self else {
                    return
                }

                self.cameraPermissionPrepared = true

                if granted {
                    AppLogger.log(
                        "Camera startup authorization check: OK."
                    )
                } else {
                    self.enterSafeMode(
                        reason:
                            "Camera permission unavailable at startup"
                    )
                }

                self.startMonitoringIfNeeded()
            }
        }
    }

    private func startMonitoringIfNeeded() {
        guard timer == nil else {
            return
        }

        let initialIdle = idleDetector.idleTime()

        logicalLastActivity =
            Date().addingTimeInterval(-initialIdle)

        AppLogger.log(
            "Initial HID idle:",
            String(format: "%.1f", initialIdle),
            "seconds"
        )

        if enabled && !safeMode {
            if !powerAssertion.acquire() {
                enterSafeMode(
                    reason: "Unable to acquire power assertion"
                )
            }
        }

        let timer = DispatchSource.makeTimerSource(
            queue: controllerQueue
        )

        timer.schedule(
            deadline: .now(),
            repeating: AppConfig.idleCheckInterval
        )

        timer.setEventHandler { [weak self] in
            self?.checkState()
        }

        self.timer = timer
        timer.resume()
    }

    private func stopInternal() {
        timer?.cancel()
        timer = nil
        checkingCamera = false
        externalAssertionPaused = false
        powerAssertion.release()

        AppLogger.log("Controller stopped.")
    }

    private func checkState() {
        guard enabled, !sleeping, !screenLocked, cameraPermissionPrepared else {
            return
        }

        let now = Date()
        let idle = idleDetector.idleTime()

        if idle <= AppConfig.activityThreshold {
            logicalLastActivity = now

            if waitingForUnlock {
                AppLogger.log(
                    "User activity detected. Resuming monitoring."
                )

                waitingForUnlock = false

                if !powerAssertion.isActive {
                    _ = powerAssertion.acquire()
                }
            }

            if safeMode && AppConfig.recoverOnUserActivity {
                AppLogger.log(
                    "User activity detected. Leaving safe mode."
                )

                safeMode = false
                safeModeUntil = nil

                if !powerAssertion.isActive {
                    if !powerAssertion.acquire() {
                        enterSafeMode(
                            reason: "Unable to reacquire power assertion"
                        )
                    }
                }
            }

            return
        }

        if waitingForUnlock {
            return
        }

        if safeMode {
            if let safeModeUntil {
                if now < safeModeUntil {
                    return
                }

                AppLogger.log(
                    "Camera failure cooldown ended. Resuming monitoring."
                )

                safeMode = false
                self.safeModeUntil = nil

                if !powerAssertion.isActive {
                    if !powerAssertion.acquire() {
                        enterSafeMode(
                            reason: "Unable to reacquire power assertion"
                        )
                        return
                    }
                }
            } else {
                return
            }
        }

        let externalAssertions =
            powerAssertionMonitor.externalDisplaySleepAssertions()

        if !externalAssertions.isEmpty {
            if !externalAssertionPaused {
                externalAssertionPaused = true

                AppLogger.log(
                    "External display-sleep assertion detected. Pausing idle detection."
                )

                for assertion in externalAssertions {
                    AppLogger.log(
                        " process=",
                        assertion.processName,
                        "pid=",
                        assertion.processID,
                        "type=",
                        assertion.type,
                        "name=",
                        assertion.name
                    )
                }
            }

            return
        }

        if externalAssertionPaused {
            externalAssertionPaused = false

            let logicalIdle =
                now.timeIntervalSince(logicalLastActivity)

            AppLogger.log(
                "External display-sleep assertion ended. Resuming idle detection. Logical idle:",
                String(format: "%.1f", logicalIdle),
                "seconds"
            )
        }

        let logicalIdle =
            now.timeIntervalSince(logicalLastActivity)

        guard logicalIdle >= AppConfig.idleThreshold else {
            return
        }

        guard !checkingCamera else {
            return
        }

        startPresenceCheck()
    }

    private func startPresenceCheck() {
        guard
            !checkingCamera,
            !externalAssertionPaused,
            !sleeping,
            !screenLocked
        else {
            return
        }

        checkingCamera = true

        AppLogger.log(
            "Idle threshold reached: starting presence check..."
        )

        cameraDetector.detectPresence { [weak self] result in
            self?.controllerQueue.async { [weak self] in
                self?.handlePresenceResult(result)
            }
        }
    }

    private func handlePresenceResult(
        _ result: CameraPresenceDetector.Result
    ) {
        checkingCamera = false

        guard enabled, !waitingForUnlock, !sleeping else {
            return
        }

        switch result {
        case .present:
            AppLogger.log(
                "Person is present. Restarting logical idle timer."
            )

            logicalLastActivity = Date()

            if !powerAssertion.isActive {
                _ = powerAssertion.acquire()
            }

        case .absent:
            AppLogger.log("No person detected.")
            lockScreen()

        case .failed:
            AppLogger.error("Camera detection failed.")

            enterSafeMode(
                reason: "Camera detection failure"
            )
        }
    }

    private func lockScreen() {
        guard enabled, !waitingForUnlock, !sleeping else {
            return
        }

        AppLogger.log(
            "No person detected. Preparing to lock."
        )

        waitingForUnlock = true
        powerAssertion.release()
        screenLocker.lock()
    }

    private func enterSafeMode(reason: String) {
        AppLogger.error(
            "Entering SAFE MODE:",
            reason
        )

        safeMode = true
        safeModeUntil =
            Date().addingTimeInterval(
                AppConfig.cameraFailureCooldown
            )

        powerAssertion.release()
        checkingCamera = false
    }
}
