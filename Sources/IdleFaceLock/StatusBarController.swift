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
            title: "自动锁定",
            action: #selector(toggleEnabled),
            keyEquivalent: ""
        )
        enabledItem.target = self
        enabledItem.state = controller.isEnabled ? .on : .off
        menu.addItem(enabledItem)

        let launchItem = NSMenuItem(
            title: "登录时启动",
            action: #selector(toggleLaunchAtLogin),
            keyEquivalent: ""
        )
        launchItem.target = self
        launchItem.state =
            SelfLaunchManager.shared.isEnabled ? .on : .off
        menu.addItem(launchItem)

        menu.addItem(.separator())

        let thresholdItem = NSMenuItem(
            title: thresholdTitle(),
            action: nil,
            keyEquivalent: ""
        )

        let thresholdMenu = NSMenu()

        for seconds in AppConfig.availableIdleThresholds {
            let item = NSMenuItem(
                title: "\(Int(seconds / 60)) 分钟",
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
            title: "立即检测",
            action: #selector(checkNow),
            keyEquivalent: ""
        )
        checkItem.target = self
        checkItem.isEnabled = controller.isEnabled
        menu.addItem(checkItem)

        menu.addItem(.separator())

        let lockSettingsItem = NSMenuItem(
            title: "锁屏设置",
            action: #selector(openLockScreenSettings),
            keyEquivalent: ""
        )
        lockSettingsItem.target = self
        menu.addItem(lockSettingsItem)

        let aboutItem = NSMenuItem(
            title: "关于 IdleFaceLock",
            action: #selector(showAbout),
            keyEquivalent: ""
        )
        aboutItem.target = self
        menu.addItem(aboutItem)

        let quitItem = NSMenuItem(
            title: "退出",
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    private func thresholdTitle() -> String {
        "空闲 \(Int(controller.currentIdleThreshold() / 60)) 分钟"
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
                    alert.messageText = "登录时启动已开启"
                    alert.informativeText = "IdleFaceLock 将重新启动一次，以便由系统在登录时自动启动。"
                    alert.alertStyle = .informational
                    alert.addButton(withTitle: "好")
                    alert.runModal()

                    NSApp.terminate(nil)
                    return
                }
            }

            rebuildMenu()
        } catch {
            AppLogger.log("Failed to change login startup: \(error)")

            let alert = NSAlert()
            alert.messageText = "操作失败"
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .warning
            alert.addButton(withTitle: "好")
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
        alert.informativeText = """
        版本 \(version)

        摄像头仅在空闲检测时短暂开启。
        人脸检测在本机完成，不保存或上传图像。

        锁定方式：
        macOS Display Sleep

        建议：
        在“系统设置 → 锁定屏幕”中，将
        “显示器关闭后要求输入密码”设置为“立即”。
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "好")
        alert.runModal()
    }

    @objc
    private func quit() {
        NSApplication.shared.terminate(nil)
    }
}
