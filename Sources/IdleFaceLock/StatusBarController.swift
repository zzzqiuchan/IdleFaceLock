import Cocoa

@MainActor
final class StatusBarController {
    private let statusItem: NSStatusItem
    private let controller: AppController

    init(controller: AppController) {
        self.controller = controller

        statusItem = NSStatusBar.system.statusItem(
            withLength: NSStatusItem.variableLength
        )

        if let button = statusItem.button {
            button.image = NSImage(
                systemSymbolName: "lock.shield",
                accessibilityDescription: "IdleFaceLock"
            )
        }

        rebuildMenu()
    }

    private func rebuildMenu() {
        let menu = NSMenu()

        let enabledItem = NSMenuItem(
            title: L.autoLock,
            action: #selector(toggleEnabled),
            keyEquivalent: ""
        )
        enabledItem.target = self
        enabledItem.state = controller.isEnabled ? .on : .off
        menu.addItem(enabledItem)

        let launchItem = NSMenuItem(
            title: L.launchAtLogin,
            action: #selector(toggleLaunchAtLogin),
            keyEquivalent: ""
        )
        launchItem.target = self
        launchItem.state =
            SelfLaunchManager.shared.isEnabled ? .on : .off
        menu.addItem(launchItem)

        menu.addItem(.separator())

        let thresholdItem = NSMenuItem(
            title: L.idleThreshold(Int(controller.currentIdleThreshold() / 60)),
            action: nil,
            keyEquivalent: ""
        )

        let thresholdMenu = NSMenu()

        for seconds in AppConfig.availableIdleThresholds {
            let item = NSMenuItem(
                title: L.idleTime(Int(seconds / 60)),
                action: #selector(setThreshold),
                keyEquivalent: ""
            )
            item.target = self
            item.tag = Int(seconds)

            if abs(
                controller.currentIdleThreshold() - seconds
            ) < 0.1 {
                item.state = .on
            }

            thresholdMenu.addItem(item)
        }

        menu.setSubmenu(thresholdMenu, for: thresholdItem)
        menu.addItem(thresholdItem)

        let checkItem = NSMenuItem(
            title: L.checkNow,
            action: #selector(checkNow),
            keyEquivalent: ""
        )
        checkItem.target = self
        checkItem.isEnabled = controller.isEnabled
        menu.addItem(checkItem)

        menu.addItem(.separator())

        let lockSettingsItem = NSMenuItem(
            title: L.lockScreenSettings,
            action: #selector(openLockScreenSettings),
            keyEquivalent: ""
        )
        lockSettingsItem.target = self
        menu.addItem(lockSettingsItem)

        let aboutItem = NSMenuItem(
            title: L.about,
            action: #selector(showAbout),
            keyEquivalent: ""
        )
        aboutItem.target = self
        menu.addItem(aboutItem)

        let quitItem = NSMenuItem(
            title: L.quit,
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    @objc
    private func toggleEnabled() {
        controller.toggleEnabled { [weak self] in
            DispatchQueue.main.async {
                self?.rebuildMenu()
            }
        }
    }

    @objc
    private func toggleLaunchAtLogin() {
        let manager = SelfLaunchManager.shared

        do {
            if manager.isEnabled {
                try manager.setEnabled(false)
            } else {
                try manager.setEnabled(true)

                if !manager.isCurrentProcessManaged {
                    let alert = NSAlert()
                    alert.messageText = L.launchAtLoginEnabled
                    alert.informativeText = L.launchAtLoginRestartMessage
                    alert.alertStyle = .informational
                    alert.addButton(withTitle: L.ok)
                    alert.runModal()

                    NSApp.terminate(nil)
                    return
                }
            }

            rebuildMenu()
        } catch {
            AppLogger.log("Failed to change login startup: \(error)")

            let alert = NSAlert()
            alert.messageText = L.operationFailed
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .warning
            alert.addButton(withTitle: L.ok)
            alert.runModal()
        }
    }

    @objc
    private func setThreshold(_ sender: NSMenuItem) {
        controller.setIdleThreshold(
            TimeInterval(sender.tag)
        ) { [weak self] in
            DispatchQueue.main.async {
                self?.rebuildMenu()
            }
        }
    }

    @objc
    private func checkNow() {
        controller.checkNow()
    }

    @objc
    private func openLockScreenSettings() {
        let urlString =
            "x-apple.systempreferences:com.apple.Lock-Screen-Settings.extension"

        guard let url = URL(string: urlString) else {
            return
        }

        NSWorkspace.shared.open(url)
    }

    @objc
    private func showAbout() {
        let version =
            Bundle.main.object(
                forInfoDictionaryKey:
                    "CFBundleShortVersionString"
            ) as? String ?? "unknown"

        let alert = NSAlert()
        alert.messageText = "IdleFaceLock"
        alert.informativeText = L.aboutMessage(version: version)
        alert.alertStyle = .informational
        alert.addButton(withTitle: L.ok)
        alert.runModal()
    }

    @objc
    private func quit() {
        NSApplication.shared.terminate(nil)
    }
}
