# PalmPad

A native iPhone trackpad and a lightweight Mac companion, built with SwiftUI, UIKit, Multipeer Connectivity, and CryptoKit. No third-party dependencies or server.

## Install

**Start with [SETUP.md](SETUP.md) for the full installation guide.**

This repository contains the native iPhone app, Mac companion, Xcode project, icons, tests, and build script. Compiled apps and personal signing settings are intentionally excluded.

1. Download this repository using **Code → Download ZIP** and extract it on your Mac, or clone it.
2. Open **PalmPad.xcodeproj** at the repository root.
3. Choose **PalmPadMac → My Mac** in Xcode and click **Run** to build the companion. Enable its Accessibility permission using **Open Settings** in the app.
4. Connect and unlock your iPhone. Select the **PalmPad** target → **Signing & Capabilities**, and choose your own Apple signing team.
5. Choose the **PalmPad** scheme and your physical iPhone, then click **Run** to install it. Complete Developer Mode setup if requested.
6. Select **Start pairing** on the Mac, **Find my Mac** on the phone, compare the codes, and approve on the Mac.

Normal use is wireless. Free Personal Team profiles expire after seven days and need refreshing from Xcode; see [SETUP.md](SETUP.md#refreshing-the-iphone-installation).

Requirements: iOS 17+, macOS 14+, Xcode with support for the phone's iOS version, and an Apple account for iPhone signing. No third-party dependencies, XcodeGen installation, or server is required to open the included project.

## Controls

| Action | Gesture or control |
| --- | --- |
| Move pointer | Slide one finger |
| Left click | Tap once, or press Left click |
| Double-click | Tap twice quickly, or press Double |
| Right click | Tap two fingers, or press Right click |
| Scroll | Move two fingers vertically or horizontally |
| Drag / select text | Hold one finger still for about half a second; feel the click, move, then lift to release |
| Tune the feel | Open the sliders button for pointer speed, scroll speed/direction, haptic strength, and screen-awake behavior |

Haptics are generated immediately on the iPhone for clicks and drag pickup/release. They approximate a crisp trackpad click; an iPhone does not reproduce a MacBook's Force Touch hardware or pressure sensing. Physical haptics require a real iPhone.

## Connection and privacy

1. Enable Accessibility permission for the Mac companion, then select **Start pairing**.
2. On the phone, select **Find my Mac**, then choose the Mac.
3. Compare the six-digit numbers on both screens. On the Mac, select **Codes match · Allow** only if they match.

Discovery names alone are not authentication. A fresh Curve25519 key exchange derives directional ChaChaPoly keys and a six-digit verification number. Mouse commands remain blocked until approval. Every new session requires confirmation; the app does not retain device credentials or reconnect silently. Multipeer Connectivity also requires encrypted sessions.

Messages use authenticated encryption, protocol version checks, sequence numbers, size limits, and bounded numeric values. One reliable ordered channel carries coalesced motion and discrete input, preserving drag/button ordering. Motion is collected at up to 60 frames per second. A one-second heartbeat closes an unresponsive established connection after approximately six seconds.

The Mac releases held buttons on disconnect, sleep/lock, quit, or permission removal. The phone disconnects on backgrounding, releases held buttons, and restores normal screen locking. A lost or interrupted pairing needs **Start pairing** again on the Mac. You can stop access from the Mac window or its menu-bar item.

There are no accounts, telemetry, remote servers, shell commands, remote file access, keyboard capture, or screen streaming in the apps. The Mac companion runs without App Sandbox because it posts global mouse events using the Accessibility permission. This is a local development build, not an App Store or notarized distribution.

## Development

Open `PalmPad.xcodeproj` directly. Choose **PalmPad** for iPhone or **PalmPadMac** for macOS. Source changes need no generation step. The checked-in project is generated from `project.yml`; XcodeGen is needed only when regenerating project structure.

```sh
# Pure gesture and cryptographic protocol tests (no mouse control or network needed)
swift test

# Build and ad-hoc sign a release Mac app
./Scripts/build-mac.sh

# Regenerate only after changing project.yml; XcodeGen is optional otherwise
xcodegen generate
```

Signing teams are intentionally unset. Set your own team for the iPhone target. If you regenerate after selecting a team in Xcode, preserve the team in your local `project.yml` first.

| Source | Responsibility |
| --- | --- |
| `Shared/Protocol.swift` | Command validation, ephemeral key agreement, encryption, replay rejection |
| `Shared/PeerLink.swift` | Discovery, single-peer pairing, approval gating, heartbeats, lifecycle |
| `Shared/Gestures.swift` | Testable multitouch gesture state machine |
| `iOS/TrackpadSurface.swift` | UIKit touch collection, cancellation, long-press timer |
| `iOS/PhoneModel.swift` | Ordered motion coalescing, haptics, user preferences |
| `iOS/PalmPadPhone.swift` | Trackpad, connection, settings, and gesture guide screens |
| `Mac/MouseDriver.swift` | Mouse movement, display bounds, click counts, scrolling, button release |
| `Mac/PalmPadMac.swift` | Permission status, pairing approval, menu bar, sleep/lock lifecycle |
| `Tests/PalmPadTests.swift` | Gesture and cryptographic regression checks |

## Validation and limits

See [VALIDATION.md](VALIDATION.md) for the checks performed on this Mac and the remaining physical-device checks. Do not treat simulator testing as proof of physical haptic feel or wireless latency.

This first version uses nearby discovery, manual approval per session, and direct two-finger scrolling. It does not implement inertial scrolling, macOS three/four-finger workspace gestures, Force Touch pressure, a remote keyboard, unattended login-screen control, or internet remote access.

## Apple references

- [Multipeer Connectivity](https://developer.apple.com/documentation/multipeerconnectivity)
- [Required session encryption](https://developer.apple.com/documentation/multipeerconnectivity/mcencryptionpreference/required)
- [Cryptographic operations with CryptoKit](https://developer.apple.com/documentation/cryptokit/performing-common-cryptographic-operations)
- [Impact haptic feedback](https://developer.apple.com/documentation/uikit/uiimpactfeedbackgenerator)
- [Accessibility trust API](https://developer.apple.com/documentation/applicationservices/1459186-axisprocesstrustedwithoptions)
