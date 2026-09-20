# IdleFaceLock

> English: [README.en.md](README.en.md)

IdleFaceLock 是一个 macOS 菜单栏小工具。键盘鼠标长时间没动时，它会短暂打开摄像头看一眼你还在不在；如果没人，就关掉显示器并触发系统重新验证。

它不是要取代 macOS 自带的自动锁屏，而是想做到「人在就继续，人走了才锁」。

**当前版本 0.5.6（长期测试版）**，欢迎提 Issue 反馈使用中的问题。

[Changelog](CHANGELOG.md) · [License](LICENSE)

## 解决什么问题

macOS 判断要不要锁屏，主要看你有没有动键盘鼠标。但有些时候你人就在屏幕前，只是没在操作：

* 看长文档、会议内容
* 等后台任务跑完
* 盯着某个程序的运行状态

这些情况下系统只看到「很久没输入」，就把屏幕锁了。IdleFaceLock 多加了一个判断条件——用摄像头确认一下有没有人。只有「既没有键鼠操作，摄像头也没看到人」时，才会关屏。

## 工作原理

平时：

* 摄像头完全关闭
* 用 macOS 的 `HIDIdleTime` 判断键鼠真实空闲时间
* 通过 `PreventUserIdleDisplaySleep` 让显示器保持唤醒
* 系统本身的睡眠策略仍由 macOS 控制

到达你设置的空闲时间后，它会短暂打开前置摄像头，取几帧画面，用 macOS Vision 在本机做人脸检测，然后立刻关掉摄像头。结果分三种：

* **检测到人**：关闭摄像头，不关闭屏幕，重新开始计时
* **没检测到人**：关闭摄像头，执行 `pmset displaysleepnow` 关屏
* **摄像头检测失败**：进入安全模式，不关闭屏幕

检测到人会尽快结束；没检测到人时会在有限帧数内多试几次，减少偶发误判。

只有**离摄像头足够近**的人脸才算「人在」。这样能区分「坐在电脑前」和「已经起身站到较远处」——比如站在椅子后面的其他人，就会被判为人已离开。判断依据是人脸在画面中所占的面积比例，默认阈值 2%（个人实测：坐着约 8%、往后靠约 3% 都算在场，站远一些约 1% 算离场）。

如果你觉得这个阈值不合适，请手动修改 `Sources/IdleFaceLock/AppConfig.swift` 里的 `minFaceAreaRatio`（值越大要求离得越近），改完重新构建即可。
检测时每帧的人脸大小和占画面比例都会打进日志（见下方「日志」一节），方便你按自己的坐姿和摄像头标定合适的值。

## 特点

* 原生 macOS 菜单栏应用，轻量、占用低
* 基于真实 HID 键鼠空闲时间，空闲后才开摄像头
* 人脸检测用 macOS Vision 本地完成，只判断「有没有人」，不做身份识别
* 不保存、不上传任何摄像头画面，不依赖云服务
* 摄像头异常时安全退出，不会强制锁定
* 能识别其他程序的「阻止休眠」状态并暂停自己
* 支持系统睡眠 / 唤醒，可选登录时启动，日志自动轮转

## 摄像头权限

程序启动时只处理一次权限：

* 已授权：直接启动
* 未决定：启动时请求一次
* 拒绝或被系统限制：进入安全模式

正常检测过程中不会反复弹权限请求。如果你之后在系统设置里重新允许，后续检测会自动恢复。程序不会在运行期间一直占用摄像头。

## 锁屏机制

锁定动作用的是：

```bash
pmset displaysleepnow
```

也就是请求 macOS 关闭显示器，**关屏后要不要重新输密码，由 macOS 自己的安全设置决定**。

如果你希望关屏后必须重新验证身份，请在 **系统设置 → 锁定屏幕** 里，把 **显示器关闭后要求输入密码** 设为 **立即**。IdleFaceLock 不会替你改这个设置。

参考 [Apple 官方说明](https://support.apple.com/en-gb/guide/mac-help/mchlp2270/mac)

它不靠模拟键鼠来锁屏，也不需要 Accessibility 权限。

## 登录时启动

默认关闭，可以在菜单栏里打开「登录时启动」。开启后由 macOS `launchd` 管理：登录后自动启动、异常退出后自动恢复、只在当前用户的 GUI session 里运行。

对应的 LaunchAgent：

```text
~/Library/LaunchAgents/com.zzzqiuchan.idlefacelock.plist
```

## 和其他程序的兼容

如果有别的程序正在阻止显示器休眠（比如 IINA、VLC、`caffeinate`，或其他用 Power Assertion 的程序），IdleFaceLock 会暂停自己的检测，不会去开摄像头。

等对方的 Power Assertion 消失后，它会接着之前的空闲计时继续，而不是从零重新计。这样播放视频、跑临时任务时就不会被误检测。

## 系统睡眠 / 唤醒

系统真正进入睡眠时，它会释放自己的 Power Assertion、暂停检测、不开摄像头。系统唤醒后重新建立 Power Assertion 并恢复监控。如果 session 已经处于锁定状态，也会暂停检测。

## 菜单

* 启用 IdleFaceLock
* 登录时启动
* 空闲时间：1 / 3 / 5 / 10 / 15 / 20 / 30 / 45 / 60 分钟
* 立即检测
* 锁屏设置
* 关于 IdleFaceLock
* 退出

空闲时间基于真实 HID 输入。比如设成 5 分钟，就是键鼠连续 5 分钟没有输入后，做一次人脸检测。

## 日志

日志在：

```text
~/Library/Logs/IdleFaceLock/current.log
```

带完整时间戳（`yyyy-MM-dd HH:mm:ss.SSS`），自动轮转：`current.log` 最大约 5 MB，最多保留 3 个历史文件，总量约 15 MB。

同时也写入 macOS Unified Logging，可以实时查看：

```bash
log stream --level debug --style compact --predicate 'subsystem == "com.zzzqiuchan.idlefacelock"'
```

## 隐私

* 摄像头平时是关的，只有到了空闲检测条件才短暂打开
* 人脸检测用 macOS Vision 在本机完成
* 不上传画面、不存照片、不存视频、不依赖云端人脸识别

摄像头只回答一个问题：**现在电脑前有没有人？** 检测完立刻关闭。

## 已知限制

* **锁定依赖显示器休眠**：用的是 `pmset displaysleepnow` 关屏，而不是某个「立即锁定 Session」的公开 API，所以建议按上面说明把「显示器关闭后要求输入密码」设为立即。
* **依赖系统摄像头权限**：如果你拒绝授权，程序不会绕过权限，也不会在权限异常时强制锁定，而是安全优先、不锁定。
* **外部程序可能主动阻止休眠**：视频播放器、`caffeinate` 等，程序会识别并暂停自己的检测。
* **主要面向现代 macOS**：提供 Apple Silicon 和 Intel 的 Universal 构建，主要在较新的 macOS 上开发和测试。

## 安装

目前以源码方式提供。进入项目目录后给脚本加执行权限并运行安装：

```bash
cd IdleFaceLock
chmod +x build-app.sh install.sh uninstall.sh
./install.sh
```

安装后默认不开启「登录时启动」，首次运行时 macOS 可能会请求摄像头权限。

也可以构建 Universal 版本，再把 `.build/IdleFaceLock.app` 拖进「应用程序」文件夹：

```bash
chmod +x build-universal-app.sh
./build-universal-app.sh
```

## 卸载

在项目目录执行：

```bash
./uninstall.sh
```

## 从源码构建

项目用 Swift Package Manager：

```bash
swift build -c release
```

也可以直接用项目自带的构建脚本：

```bash
./build-app.sh
```

## 项目结构

```text
IdleFaceLock/
├── Package.swift
├── Resources/
│   ├── Info.plist
│   └── IdleFaceLock.icns
├── Sources/
│   └── IdleFaceLock/
│       ├── main.swift
│       ├── AppConfig.swift
│       ├── AppController.swift
│       ├── AppDelegate.swift
│       ├── AppLogger.swift
│       ├── CameraPresenceDetector.swift
│       ├── IdleDetector.swift
│       ├── Localizer.swift
│       ├── PowerAssertion.swift
│       ├── PowerAssertionMonitor.swift
│       ├── ScreenLocker.swift
│       ├── SelfLaunchManager.swift
│       └── StatusBarController.swift
├── build-app.sh
├── build-universal-app.sh
├── install.sh
└── uninstall.sh
```

## 技术栈

* **Swift** — 主要开发语言
* **AppKit** — 菜单栏应用及 macOS UI
* **AVFoundation** — 摄像头采集
* **Vision** — 本地人脸检测
* **IOKit** — HID 空闲时间及电源状态
* **launchd** — 登录时启动及进程管理
* **macOS Unified Logging** — 系统日志

## License

本项目采用 [MIT License](LICENSE)。
