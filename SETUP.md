# Use PalmPad on your iPhone and Mac

Updated September 5, 2026 · PalmPad 1.0.0

You will install **two apps**: the Mac companion and the iPhone trackpad. Xcode is needed for the first iPhone installation and later signing refreshes. You do not need Terminal, Homebrew, XcodeGen, or a server for the normal installation.

## Before you begin

- **Mac:** macOS 14 or later. The Mac companion can be built locally for Apple silicon or Intel.
- **iPhone:** iOS 17 or later, unlocked and connected to the Mac with a cable for setup.
- **Xcode:** install Xcode from the Mac App Store if needed, open it once, and finish any component setup. Its iOS support must be compatible with your phone's iOS version. This project was checked with Xcode 26.6.
- **Apple account:** your own account for signing the iPhone app. A free Personal Team can be used for personal testing; its installation must be refreshed periodically.
- **Connection:** Wi-Fi and Bluetooth enabled on both devices. Begin with both on the same Wi-Fi network.

**Current status:** both apps have been built and the iPhone interface tested in the simulator. Physical-device pairing, pointer injection, and haptics still need end-to-end validation. See [VALIDATION.md](VALIDATION.md).

## Download the source

On GitHub, choose **Code → Download ZIP**, then extract the ZIP on your Mac. Alternatively, clone the repository. Open the extracted repository folder, which contains:

```text
PalmPad.xcodeproj     ← Open this in Xcode
Mac/                 ← Mac companion source
iOS/                ← iPhone app source
Shared/              ← Gestures and encrypted connection
Scripts/build-mac.sh ← Optional command-line Mac build
README.md
SETUP.md             ← This guide
```

There is no prebuilt Mac app or installable iPhone IPA in this source repository. Sending the ZIP to your phone will not install PalmPad.

## 1. Build and open the Mac companion

1. Open **PalmPad.xcodeproj** at the repository root.
2. In Xcode's top toolbar, choose the **PalmPadMac** scheme and **My Mac** as the destination.
3. Click **Run ▶**. If Xcode requests a signing selection for the Mac target, choose **Sign to Run Locally**. Basic local macOS runs do not require device provisioning; see [Apple's device-running guide](https://developer.apple.com/documentation/xcode/running-your-app-on-simulated-or-physical-devices).
4. When PalmPad opens, click **Open Settings**.
5. In **System Settings → Privacy & Security → Accessibility**, enable **PalmPad Mac**. Authenticate on the Mac if asked. If the app is missing, add the built app with **+**; find it through Xcode's Products group → **PalmPad Mac.app → Show in Finder**.
6. Return to PalmPad. It should display **Mouse control is ready** and enable **Start pairing**.

For a standalone release build, run `./Scripts/build-mac.sh` from the repository folder in Terminal. The script creates **Build/PalmPad Mac.app**. You may move that app to Applications before granting Accessibility permission, for a stable installation path. Avoid running the Xcode copy and Applications copy at the same time.

Accessibility lets the companion move and click the Mac mouse. Allow Local Network access if asked so the devices can discover each other. After rebuilding or moving the app, macOS may require replacing its old Accessibility entry with the current app.

## 2. Put PalmPad on your iPhone

Perform these steps in **Xcode on your Mac**, keeping the iPhone connected:

1. Connect the iPhone with a cable, unlock it, and accept **Trust This Computer** if asked.
2. Open **PalmPad.xcodeproj**.
3. In **Xcode → Settings → Apple Accounts** (called **Accounts** in some versions), add your own Apple account if needed. Complete Apple's sign-in prompts yourself, then close Settings.
4. Select the PalmPad project in the left sidebar. Under **Targets**, select **PalmPad** (the iPhone target).
5. Open **Signing & Capabilities**, keep **Automatically manage signing** enabled, and choose your **Personal Team** or developer team. If the bundle identifier is unavailable, replace `com.palmpad.iphone` with a unique identifier such as `com.yourname.palmpad`.
6. In the top toolbar, choose the **PalmPad** scheme and your **physical iPhone**, then click **Run ▶**. Select the device under connected devices, not an entry under **iOS Simulators** and not **Any iOS Device**. The scheme name **PalmPadMac** is for the companion, not your phone.
7. If Xcode asks for Developer Mode, enable it on the iPhone under **Settings → Privacy & Security → Developer Mode** and complete the restart/confirmation on the phone. Re-run from Xcode afterward.

Developer Mode may not appear until the phone has started pairing with Xcode. If Xcode shows a device-preparation or iOS-component download, let it finish before running again.

**Success check:** PalmPad opens on the actual iPhone and displays **Make yourself comfortable.** with a **Find my Mac** button. If only a simulated iPhone window opens on the Mac, change the run destination to your physical phone and run again.

Apple documents [device signing and running from Xcode](https://developer.apple.com/documentation/xcode/running-your-app-on-simulated-or-physical-devices) and [enabling Developer Mode](https://developer.apple.com/documentation/xcode/enabling-developer-mode-on-a-device). A free Personal Team supports personal device testing, but provisioning profiles expire after seven days; run again from Xcode to refresh the installation. Paid membership is needed for distribution options such as TestFlight. See [Apple's membership comparison](https://developer.apple.com/support/compare-memberships/).

The simulator is useful for checking screens, but it cannot verify the iPhone's physical haptic feedback.

## 3. Connect wirelessly

1. Keep Wi-Fi and Bluetooth on. Start with both devices on the same Wi-Fi network.
2. On the Mac, choose **Start pairing**.
3. On the iPhone, open PalmPad and tap **Find my Mac**, then tap your Mac's name.
   Allow **Local Network** access if either device asks. If the list is empty, give discovery a moment and confirm the Mac still shows that it is waiting for your iPhone.
4. Compare the six-digit code on both screens. On the Mac, click **Codes match · Allow** if they match.
5. Start using the touch surface. You can unplug the cable after installation; the app uses a nearby wireless connection.

**Success check:** the iPhone shows **Connected**, the Mac shows **Connected to …**, and moving one finger on the phone moves the Mac's pointer. Matching pairing codes alone does not mean access has been approved yet.

Close the Mac window when you want; PalmPad remains available from its hand-shaped menu-bar icon. Close or background the iPhone app to disconnect. To reconnect, start pairing on the Mac again.

## Everyday use

1. Keep the Mac companion running and the Mac awake and unlocked.
2. Click **Start pairing** on the Mac and connect from PalmPad on your phone.
3. Compare the codes and approve each new session. No cable or Xcode window is needed during normal use while the phone installation is still valid.
4. Tap once for left click, twice for double-click, or with two fingers for right-click. Slide two fingers to scroll. Hold one finger still until the click feedback, then move to drag or select text; lift to release.
5. Use the sliders button on the phone to adjust pointer speed, scrolling, and haptic strength. Use the **?** button for the gesture guide.
6. Choose **Disconnect iPhone** on the Mac, use its menu-bar disconnect control, or leave the phone app to end the session. Re-pair after the phone backgrounds or the Mac sleeps/locks.

## Refreshing the iPhone installation

When a free Personal Team provisioning profile expires after seven days, reconnect and unlock the phone, open the **same project**, select **PalmPad** and the physical phone, then click **Run ▶** again. Keep the same team and bundle identifier to update the existing installation. Do not delete the phone app first unless you intend to discard its saved settings.

## If something does not work

| Symptom | What to check |
| --- | --- |
| Xcode says a development team is required | Select the **PalmPad** iPhone target → **Signing & Capabilities** → choose your team. If none is listed, add your Apple account in Xcode Settings. |
| Bundle identifier cannot be registered | Change the iPhone target's bundle identifier to a unique value, keep automatic signing enabled, and retry. |
| Xcode says no eligible devices are connected | Unlock the phone, check the cable supports data, accept the trust prompt, and check Xcode's device manager. Finish device pairing and Developer Mode setup; install compatible iOS support if Xcode requests it. |
| Developer Mode is missing | First connect the phone and start pairing with Xcode, then check **Settings → Privacy & Security** on the phone again. |
| Phone says the developer is untrusted | Follow the on-device prompt. If instructed, open **Settings → General → VPN & Device Management** and trust your own development profile. Then run again from Xcode. |
| Mac not listed | Start pairing on the Mac, keep both devices awake, enable Wi-Fi/Bluetooth, and allow Local Network access on both devices. Try the same non-guest Wi-Fi network. Networks with client isolation and some VPNs can block nearby discovery. |
| Cannot enable pairing | Enable **PalmPad Mac** under Accessibility. The app checks once per second. |
| Connected but pointer does not move | Check the current app's Accessibility entry. If the app was rebuilt/moved, remove its old entry, add the current app, relaunch, and pair again. |
| Connection times out | Keep the phone in PalmPad. Start pairing on the Mac again; each attempt gets a fresh code. |
| Phone reports Local Network denied | Enable **Settings → Apps → PalmPad → Local Network**, then retry. On older iOS versions, find PalmPad directly in Settings. |
| Mac reports Local Network denied | Enable PalmPad Mac under **System Settings → Privacy & Security → Local Network** if present. |
| Scrolling feels backward | Toggle **Natural scrolling** in PalmPad's settings. |
| No haptics | Check **Haptic clicks** and **Strength** in PalmPad settings; test on the real phone, not the simulator. System/device settings may also affect feedback. |
| iPhone app stops opening after several days | Refresh a free Personal Team installation by connecting the phone and running it again from Xcode. |
| App icon build reports missing simulator runtime | Install the needed iOS simulator runtime in Xcode's Components settings and build through Xcode. Restricted command environments can also block the simulator service even when the runtime is installed. |

## Quick physical-device check

Move the pointer; single-click an item; double-click a test folder; two-finger tap for a context menu; scroll a long page; hold and drag to select text; then background the phone app during a harmless drag and confirm the mouse releases. Adjust speed and haptic strength to taste.
