# Validation — September 5, 2026

## Completed

- Built the native macOS target in Debug and Release with Xcode 26.6.
- Packaged `PalmPad Mac.app`, ad-hoc signed it, and passed `codesign --verify --deep --strict`.
- Launched the delivered Mac app and visually checked the window, permission explanation, and disabled-until-authorized pairing control.
- Compiled the iPhone source for the physical-device SDK without signing.
- Built the full iPhone app, including its app icon, through Xcode and ran it on the iPhone 17 Pro simulator with iOS 26.5.
- Visually checked the actual iPhone trackpad, connection/discovery sheet, and pointer/scroll/haptic settings.
- Ran the Swift package test suite: **15 tests, 0 failures**.
- Syntax-checked the supplied Mac build script.

The 15 tests cover:

1. Matching pairing numbers and encrypted messages in both directions.
2. Refusal to send or decode commands before establishing keys.
3. Rejection of replayed and out-of-order messages.
4. Rejection of tampered ciphertext.
5. Rejection of old-session ciphertext after re-pairing.
6. Rejection of reflected keys, repeated key exchange, malformed keys, and reflected messages.
7. Oversized payloads, non-finite coordinates, excessive movement, and invalid click counts.
8. Single and double tap click counts.
9. Slow/distant second taps staying single clicks.
10. Relative pointer movement without a trailing click.
11. Two-finger right-click with fingers lifting at slightly different times.
12. Two-finger scrolling without accidental pointer movement or clicks during lift-off.
13. Long-press pickup, drag movement, and release.
14. Drag cancellation and a second finger releasing a held button.
15. Movement canceling long press and three-finger input being ignored.

## Still needs a physical-device test

Physical iPhone installation was not part of the recorded validation. Select a local signing team and connect a development device to perform this check.

Mac Accessibility access was not granted during this build. Consequently, actual cross-device pairing and pointer injection, physical multi-display behavior, wireless latency, sleep/disconnect behavior while holding a real mouse button, and physical haptic strength remain unverified end to end. Their implementations are present; passing core tests does not replace these device checks.

## Build environment note

The initial restricted command environment could not access simulator/device services; normal Xcode simulator builds succeeded. Simulator discovery emitted network diagnostics, so real-device connection reliability remains unverified. No system security protections were disabled.
