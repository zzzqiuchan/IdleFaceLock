import Foundation
enum L {
    private static let isChinese =
        Locale.current.language.languageCode?.identifier == "zh"

    private static func text(
        _ chinese: String,
        _ english: String
    ) -> String {
        isChinese ? chinese : english
    }

    static let autoLock =
        text("启用 IdleFaceLock", "Enable IdleFaceLock")

    static let launchAtLogin =
        text("登录时启动", "Launch at Login")

    static let checkNow =
        text("立即检测", "Check Now")

    static let lockScreenSettings =
        text("锁屏设置", "Lock Screen Settings")

    static let about =
        text("关于 IdleFaceLock", "About IdleFaceLock")

    static let quit =
        text("退出", "Quit")

    static let ok =
        text("好", "OK")

    static let operationFailed =
        text("操作失败", "Operation Failed")

    static let launchAtLoginEnabled =
        text(
            "登录时启动已开启",
            "Launch at Login Enabled"
        )

    static let launchAtLoginRestartMessage =
        text(
            "IdleFaceLock 将重新启动一次，以便由系统在登录时自动启动。",
            "IdleFaceLock will restart once so that macOS can launch it automatically at login."
        )

    static func idleThreshold(_ minutes: Int) -> String {
        if isChinese {
            return "空闲 \(minutes) 分钟"
        }

        return minutes == 1
            ? "Idle for 1 minute"
            : "Idle for \(minutes) minutes"
    }

    static func idleTime(_ minutes: Int) -> String {
        if isChinese {
            return "\(minutes) 分钟"
        }

        return minutes == 1
            ? "1 minute"
            : "\(minutes) minutes"
    }

    static func aboutMessage(version: String) -> String {
        if isChinese {
            return """
            版本 \(version)

            摄像头仅在空闲检测时短暂开启。
            人脸检测在本机完成，不保存或上传图像。

            锁定方式：
            macOS Display Sleep

            建议：
            在“系统设置 → 锁定屏幕”中，将
            “显示器关闭后要求输入密码”设置为“立即”。
            """
        }

        return """
        Version \(version)

        The camera is activated briefly only when idle detection is triggered.
        Face detection is performed locally. No images are saved or uploaded.

        Lock method:
        macOS Display Sleep

        Recommendation:
        In “System Settings → Lock Screen”, set
        “Require password after screen saver begins or display is turned off”
        to “Immediately”.
        """
    }
}