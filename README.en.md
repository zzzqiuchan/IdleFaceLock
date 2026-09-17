# IdleFaceLock

IdleFaceLock is a lightweight macOS menu bar app. When there's no keyboard or mouse activity for a while, it briefly opens the camera to check whether you're still there. If no one is detected, it turns off the display and lets macOS re-lock.

It's not a replacement for macOS auto-lock — it just adds one more condition: only lock when there's *both* no input *and* no one in front of the screen.

> 中文说明见 [README.md](README.md)。

## How it works

- Normally the camera stays off; idle time is measured from real keyboard/mouse activity (`HIDIdleTime`).
- After your configured idle time, it briefly opens the front camera, grabs a few frames, and runs local face detection with macOS Vision — then closes the camera immediately.
- **Someone detected** → stay unlocked. **No one** → run `pmset displaysleepnow`. **Camera error** → safe mode, stay unlocked.

## Highlights

- Native macOS menu bar app, lightweight and unobtrusive
- Local face detection only (presence check, no identity recognition)
- Never stores or uploads camera footage; no cloud service
- Pauses itself when other apps block display sleep (IINA, VLC, `caffeinate`, etc.)
- Optional launch at login, automatic log rotation

## Note

IdleFaceLock uses `pmset displaysleepnow` to turn off the display. Whether a password is required afterward is up to macOS. To make sure re-authentication is required, set **System Settings → Lock Screen → Require password after screen turns off** to **immediately**.

## Install

```bash
cd IdleFaceLock
chmod +x build-app.sh install.sh uninstall.sh
./install.sh
```

See [README.md](README.md) for full details, build options, and uninstall steps.

## License

[MIT License](LICENSE)
