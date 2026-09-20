# Changelog

All notable changes to IdleFaceLock are documented in this file.

## [0.5.6] - 2026-09-20

### Added

* publish the universal build to GitHub Releases, with a one-line download-and-install command in the README

### Changed

* only count a face as present when it is close enough (area >= minFaceAreaRatio)
* ad-hoc sign the app during the build so camera permission (TCC) works on downloaded copies
* increase overall detection timeout to 2.0s to accommodate camera warmup/first-frame latency
* update Workflow
* update README

### Bugfix

* camera detection timeout with no analyzable frames is now treated as a failure (safe mode) instead of "no person", so a camera glitch no longer locks the screen

## [0.5.5] - 2026-09-18

### Changed

* try `VNDetectFaceRectanglesRequestRevision3` to optimize face detection logic

## [0.5.4] - 2026-09-16

### Changed

* delete some unnecessary log
* adjust face frames threshold, set requiredFaceFrames = 2

## [0.5.3] - 2026-09-16

### Added

* new Github workflow
* new Bundle ID

### Bugfix

* screen not sleep, when manual lock

## [0.5.2] - 2026-09-16

### Added

* Localizer: Chinese and English

## [0.5.1] - 2026-09-16

### Added

* detail README and CHANGELOG

## [0.5.0] - 2026-09-16

### Added

* macOS menu bar application
* Configurable idle detection threshold
* Real HID idle time detection through `HIDIdleTime`
* Local face detection using macOS Vision
* Short-duration camera activation only when an idle check is triggered
* Automatic camera shutdown immediately after detection
* Safe mode when camera access or camera detection fails
* Automatic lock action using `pmset displaysleepnow`
* Detection of macOS screen lock and unlock state
* Pause of monitoring while the session is locked
* Detection of external display-sleep Power Assertions
* Compatibility with applications such as IINA, VLC and `caffeinate`
* Preservation of logical idle time when external display-sleep assertions are active
* Sleep/wake handling
* Optional login-at-startup support using `launchd`
* Menu bar controls
* Configurable idle thresholds like:
  * 1 minute
  * 3 minutes
  * 5 minutes
  * 10 minutes
  * ...
* Manual "立即检测" action
* Rotating application log files
* macOS Unified Logging support
* Custom application icon

### Privacy

* Camera is normally off
* Camera is activated only during presence detection
* Face detection is performed locally using Vision
* No photos are saved
* No video is recorded or uploaded
* No cloud-based face recognition service is required

### Notes

0.5.0 is intended as a long-term testing release.

The current lock implementation requests macOS display sleep with:

```bash
pmset displaysleepnow
```

Users should configure macOS to require a password immediately after the display is turned off.

### Known limitations

* The current implementation relies on macOS display sleep rather than a documented public API for directly locking the current login session.
* Camera detection requires macOS camera permission.
* External applications can temporarily prevent display sleep using Power Assertions.
* The project is currently developed and tested primarily on modern macOS systems and Apple Silicon Macs.
