# IdleFaceLock 0.4.0

一个只在 Mac 长时间空闲后短暂使用摄像头判断“人是否还在”的菜单栏工具。

## 工作原理

正常使用时：

- 摄像头完全关闭
- 使用 `HIDIdleTime` 判断真实的键盘/鼠标空闲时间
- IdleFaceLock 使用 `PreventUserIdleDisplaySleep` 保持显示器不因系统自身的空闲策略而关闭

达到设定的空闲时间后：

1. 短暂打开前置摄像头
2. 获取少量视频帧
3. 使用 macOS Vision 在本机检测人脸
4. 检测完成后立即关闭摄像头

结果：

- 检测到人：不锁定，重新开始计时
- 没检测到人：关闭摄像头并执行 `pmset displaysleepnow`
- 摄像头检测失败：进入安全模式，**不锁定**

## 摄像头权限

程序启动时只处理一次摄像头权限：

- 已授权：直接启动
- 未决定：启动时请求一次
- 拒绝/受限制：进入安全模式

正常检测过程中不会反复弹出权限请求。

如果之后在系统设置中重新允许摄像头，IdleFaceLock 后续检测会自动恢复。

## 锁屏安全设置

IdleFaceLock 使用 macOS Display Sleep 作为锁定动作。

为了确保显示器关闭后必须重新验证身份，请在：

**系统设置 → 锁定屏幕**

将：

**显示器关闭后要求输入密码**

设置为：

**立即**

Apple 对该设置的说明见：
https://support.apple.com/en-gb/guide/mac-help/mchlp2270/mac

IdleFaceLock 不会修改这个系统安全设置。

## 登录时启动

默认：

**关闭**

菜单栏中可以打开：

**登录时启动**

开启后使用 `launchd` 管理：

- 登录后自动启动
- 异常退出后自动恢复
- 仅在当前用户的 GUI session 中运行

LaunchAgent：

`~/Library/LaunchAgents/com.idlefacelock.app.plist`

## 外部程序兼容

如果其他程序正在阻止显示器休眠，IdleFaceLock 会暂停自己的空闲检测计时。

例如：

- IINA
- VLC
- `caffeinate`
- 其他使用 macOS Power Assertion 的程序

外部 Assertion 消失后，会继续原来的逻辑计时，而不是重新从零开始。

## 系统睡眠/唤醒

系统真正进入 Sleep 时：

- 释放 IdleFaceLock 自己的 Power Assertion
- 暂停检测

系统唤醒后：

- 重新建立 Power Assertion
- 重新开始监控

## 日志

日志位于：

`~/Library/Logs/IdleFaceLock/current.log`

日志带完整时间戳：

`yyyy-MM-dd HH:mm:ss.SSS`

日志自动轮转：

- `current.log` 最大约 5 MB
- 最多保留 3 个历史文件
- 总量约 15 MB

同时也写入 macOS Unified Logging：

```bash
log stream --predicate 'subsystem == "com.idlefacelock.app"'
```

## 菜单

- 自动锁定
- 登录时启动
- 空闲时间：1 / 3 / 5 / 10 分钟
- 立即检测
- 锁屏设置
- 关于 IdleFaceLock
- 退出

## 安装

```bash
chmod +x build-app.sh install.sh uninstall.sh
./install.sh
```

安装后默认不会开启“登录时启动”。

## 卸载

```bash
./uninstall.sh
```

## 隐私

IdleFaceLock 的设计目标是：

- 摄像头平时关闭
- 只在空闲检测时短暂开启
- 人脸检测在本机执行
- 不保存照片
- 不上传摄像头画面
