# IdleFaceLock 0.5

> **长期测试版本**

一个 macOS 菜单栏工具：**电脑长时间没有键盘/鼠标操作后，短暂使用摄像头确认用户是否仍在电脑前；如果检测不到人，则关闭显示器并触发系统重新验证。**

IdleFaceLock 的目标不是替代 macOS 自带的自动锁屏，而是提供一种更接近“**人在电脑前就继续工作，人离开后再锁定**”的使用方式。

### ✨ Features

* 🖥️ macOS 原生菜单栏应用
* ⏱️ 基于真实 HID 键盘/鼠标空闲时间
* 📷 空闲后才短暂开启摄像头
* 👤 使用 macOS Vision 本地检测人脸
* 🔒 检测不到人后关闭显示器
* 🛡️ 摄像头异常时安全退出，不强制锁定
* ⏸️ 自动识别外部程序的显示器休眠阻止状态
* 🔋 支持系统 Sleep / Wake
* 🚀 可选 `launchd` 登录时启动
* 📝 日志自动轮转
* 🔐 不保存、不上传摄像头画面

---

**当前版本：0.5.3**

0.5 是当前的长期测试版本。如果你希望帮助测试，可以提交 Issue 或反馈实际使用中的问题。

[Changelog](CHANGELOG.md) · [License](LICENSE)

## 工作原理

正常使用时：

* 摄像头完全关闭
* 使用 macOS `HIDIdleTime` 判断真实的键盘/鼠标空闲时间
* IdleFaceLock 使用 `PreventUserIdleDisplaySleep` 保持显示器处于唤醒状态
* 系统本身的睡眠策略仍然由 macOS 控制

达到设定的空闲时间后：

1. 短暂打开前置摄像头
2. 获取少量视频帧
3. 使用 macOS Vision 在本机进行人脸检测
4. 检测完成后立即关闭摄像头

检测结果：

* **检测到人**：不锁定，重新开始空闲计时
* **未检测到人**：关闭摄像头，然后执行 `pmset displaysleepnow`
* **摄像头检测失败**：进入安全模式，**不锁定**

检测到人时会尽快结束检测；如果没有检测到人，则会在有限的帧数内继续尝试，以降低偶发误判的概率。

## 为什么需要摄像头？

macOS 的传统自动锁定主要基于“用户是否操作电脑”判断。

但实际使用中可能出现：

* 正在看视频，但没有操作键盘/鼠标
* 阅读长文档
* 开会或观看会议内容
* 等待后台任务完成
* 长时间观察某个程序运行状态

这些情况下，用户可能仍然坐在电脑前，但系统看到的是“长时间没有输入”。

IdleFaceLock 使用摄像头进行一次非常短暂的本地检测，将：

> **“没有键盘/鼠标操作”**

进一步判断为：

> **“没有键盘/鼠标操作，并且摄像头没有检测到人”**

因此只有在两个条件同时满足时才执行锁定动作。

## 摄像头权限

程序启动时只处理一次摄像头权限：

* 已授权：直接启动
* 未决定：启动时请求一次
* 拒绝或受系统限制：进入安全模式

正常检测过程中不会反复弹出权限请求。

如果之后在系统设置中重新允许摄像头，IdleFaceLock 后续检测可以自动恢复。

IdleFaceLock 不会在正常运行期间持续占用摄像头。

## 锁屏机制

IdleFaceLock 当前使用：

```bash
pmset displaysleepnow
```

作为锁定动作。

也就是说，IdleFaceLock 请求 macOS 关闭显示器，而**是否需要重新输入密码由 macOS 自己的安全设置决定**。

为了确保显示器关闭后必须重新验证身份，请在：

**系统设置 → 锁定屏幕**

将：

**显示器关闭后要求输入密码**

设置为：

**立即**

Apple 对相关设置的说明：

https://support.apple.com/en-gb/guide/mac-help/mchlp2270/mac

IdleFaceLock **不会修改**这个系统安全设置。

### 注意

IdleFaceLock 不通过模拟键盘输入、鼠标操作等方式实现锁定，也不需要 Accessibility 权限。

## 登录时启动

默认：

**关闭**

可以从菜单栏开启：

**登录时启动**

开启后使用 macOS `launchd` 管理：

* 登录后自动启动
* 异常退出后自动恢复
* 仅在当前用户的 GUI session 中运行

LaunchAgent：

```text
~/Library/LaunchAgents/com.zzzqiuchan.idlefacelock.plist
```

## 外部程序兼容

如果其他程序正在阻止显示器休眠，IdleFaceLock 会暂停自己的空闲检测。

例如：

* IINA
* VLC
* `caffeinate`
* 其他使用 macOS Power Assertion 的程序

暂停期间不会因为 IdleFaceLock 自己的计时器达到阈值而启动摄像头检测。

当外部 Power Assertion 消失后，会继续之前的**逻辑空闲计时**，而不是简单地从零开始计时。

这样可以避免例如播放视频、执行临时任务或使用 `caffeinate` 时发生意外检测。

## 系统睡眠 / 唤醒

系统真正进入 Sleep 时：

* 释放 IdleFaceLock 自己的 Power Assertion
* 暂停空闲检测
* 不启动摄像头

系统唤醒后：

* 重新建立 Power Assertion
* 恢复空闲监控

如果 macOS session 已经处于锁定状态，IdleFaceLock 也会暂停摄像头检测。

## 菜单

当前菜单包括：

* 自动锁定
* 登录时启动
* 空闲时间：1 / 3 / 5 / 10 分钟
* 立即检测
* 锁屏设置
* 关于 IdleFaceLock
* 退出

### 空闲时间

空闲时间基于真实 HID 输入空闲时间，而不是应用自己的计时器。

例如设置为：

```text
5 分钟
```

表示键盘/鼠标连续 5 分钟没有产生用户输入后，进入一次人员检测。

## 日志

日志位于：

```text
~/Library/Logs/IdleFaceLock/current.log
```

日志带完整时间戳：

```text
yyyy-MM-dd HH:mm:ss.SSS
```

日志会自动轮转：

* `current.log` 最大约 5 MB
* 最多保留 3 个历史文件
* 总量约 15 MB

同时写入 macOS Unified Logging。

可以使用：

```bash
log stream --level debug --style compact --predicate 'subsystem == "com.zzzqiuchan.idlefacelock"'
```

查看实时日志。

## 隐私

IdleFaceLock 的设计原则是：

* **摄像头平时关闭**
* 只有达到空闲检测条件时才短暂开启摄像头
* 人脸检测使用 macOS Vision 在本机执行
* 不上传摄像头画面
* 不保存照片
* 不保存视频
* 不依赖云端人脸识别服务

摄像头的主要用途只是回答一个简单的问题：

> **当前电脑前是否有人？**

检测完成后立即关闭摄像头。

## 当前限制

### 1. 锁定动作依赖 macOS 的显示器休眠

当前版本使用：

```bash
pmset displaysleepnow
```

触发显示器关闭，而不是调用一个公开的 macOS “立即锁定当前用户 Session” API。

因此建议按照上面的说明，将 macOS：

**显示器关闭后要求输入密码**

设置为：

**立即**

### 2. 摄像头检测依赖系统摄像头权限

如果用户拒绝摄像头权限，IdleFaceLock 不会绕过系统权限，也不会在权限异常时强制锁定。

摄像头检测失败时采用：

**安全优先 → 不锁定**

### 3. 外部程序可能主动阻止显示器休眠

例如视频播放器、`caffeinate` 或其他 Power Assertion。

IdleFaceLock 会识别这些情况并暂停自己的检测逻辑。

### 4. 当前主要面向现代 macOS 环境，提供 Apple Silicon 和 Intel 的 Universal 构建

项目使用 macOS 原生：

* Swift
* AVFoundation
* Vision
* IOKit
* AppKit
* launchd

目前主要针对现代 macOS 环境进行开发和测试。

## 安装

当前版本以源码方式提供。

首先进入项目目录：

```bash
cd IdleFaceLock
```

赋予脚本执行权限：

```bash
chmod +x build-app.sh install.sh uninstall.sh
```

执行安装：

```bash
./install.sh
```

安装后默认不会开启“登录时启动”。

首次运行时，macOS 可能会请求摄像头权限。

另外也可以执行
```bash
chmod +x build-universal-app.sh
./build-universal-app.sh
```
构建出来 universal 的 app 。
然后手动将`.build/IdleFaceLock.app` 拖到应用程序文件夹。

## 卸载

在项目目录执行：

```bash
./uninstall.sh
```

## 从源码构建

项目使用 Swift Package Manager：

```bash
swift build -c release
```

也可以直接使用项目提供的构建脚本：

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
├── install.sh
└── uninstall.sh
```

## 技术栈

* **Swift**
* **AppKit** — 菜单栏应用及 macOS UI
* **AVFoundation** — 摄像头采集
* **Vision** — 本地人脸检测
* **IOKit** — HID 空闲时间及电源状态
* **launchd** — 登录时启动及进程管理
* **macOS Unified Logging** — 系统日志

## License

本项目采用 [MIT License](LICENSE)。

---

**IdleFaceLock 0.5**

一个尽量简单、尽量本地化的 macOS 自动锁定工具。
