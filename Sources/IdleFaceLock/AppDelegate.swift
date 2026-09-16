import Cocoa

@MainActor
final class AppDelegate:
    NSObject,
    NSApplicationDelegate {

    private var controller: AppController!
    private var statusBarController: StatusBarController!
    private var workspaceObservers: [NSObjectProtocol] = []

    func applicationDidFinishLaunching(
        _ notification: Notification
    ) {
        controller = AppController()

        statusBarController = StatusBarController(
            controller: controller
        )

        let center = NSWorkspace.shared.notificationCenter

        workspaceObservers.append(
            center.addObserver(
                forName: NSWorkspace.willSleepNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.controller.handleWillSleep()
                }
            }
        )

        workspaceObservers.append(
            center.addObserver(
                forName: NSWorkspace.didWakeNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.controller.handleDidWake()
                }
            }
        )

        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(screenDidLock),
            name: Notification.Name("com.apple.screenIsLocked"),
            object: nil
        )

        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(screenDidUnlock),
            name: Notification.Name("com.apple.screenIsUnlocked"),
            object: nil
        )

        AppLogger.log("========================================")
        AppLogger.log("IdleFaceLock started")
        AppLogger.log(
            "Version:",
            Bundle.main.object(
                forInfoDictionaryKey: "CFBundleShortVersionString"
            ) as? String ?? "unknown"
        )
        AppLogger.log(
            "Idle threshold:",
            "\(Int(AppConfig.idleThreshold)) seconds"
        )
        AppLogger.log("Camera detection: idle-triggered only")
        AppLogger.log("Camera permission: checked/requested once at startup")
        AppLogger.log("Power assertion: enabled")
        AppLogger.log("External display assertions: monitored")
        AppLogger.log("Lock command: pmset displaysleepnow")
        AppLogger.log(
            "Login at startup:",
            SelfLaunchManager.shared.isEnabled
        )
        AppLogger.log("========================================")

        controller.start()
    }

    func applicationWillTerminate(
        _ notification: Notification
    ) {
        for observer in workspaceObservers {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }

        DistributedNotificationCenter.default().removeObserver(
            self,
            name: Notification.Name("com.apple.screenIsLocked"),
            object: nil
        )

        DistributedNotificationCenter.default().removeObserver(
            self,
            name: Notification.Name("com.apple.screenIsUnlocked"),
            object: nil
        )

        workspaceObservers.removeAll()
        controller.stop()
    }

    @objc
    private func screenDidLock() {
        controller.handleScreenLocked()
    }

    @objc
    private func screenDidUnlock() {
        controller.handleScreenUnlocked()
    }
}
