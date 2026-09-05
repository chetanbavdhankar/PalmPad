import SwiftUI

private let mint = Color(red: 0.70, green: 0.91, blue: 0.76)
private let padBackground = Color(red: 0.065, green: 0.085, blue: 0.078)

@main
struct PalmPadPhoneApp: App {
    @StateObject private var model = PhoneModel()
    @Environment(\.scenePhase) private var scenePhase
    var body: some Scene {
        WindowGroup {
            PhoneHome(model: model, link: model.link)
                .preferredColorScheme(.dark)
                .onChange(of: scenePhase) { _, phase in
                    // Local Network and system permission dialogs temporarily make the app
                    // inactive. Only a real background transition should tear down pairing.
                    if phase == .background { model.suspend() }
                }
        }
    }
}

private struct PhoneHome: View {
    @ObservedObject var model: PhoneModel
    @ObservedObject var link: PeerLink
    @State private var connections = false
    @State private var settings = false
    @State private var help = false
    @State private var contact: CGPoint?
    @State private var fingerCount = 0

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 20) {
                header
                HStack(alignment: .lastTextBaseline) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Make yourself\ncomfortable.")
                            .font(.system(size: geometry.size.height < 650 ? 29 : 36, weight: .medium, design: .rounded))
                            .tracking(-1.2).fixedSize(horizontal: false, vertical: true)
                        Text("Your Mac is within reach.").font(.system(size: 13)).foregroundStyle(.white.opacity(0.46))
                    }
                    Spacer()
                    Button { help = true } label: {
                        Image(systemName: "questionmark").font(.system(size: 13, weight: .semibold))
                            .frame(width: 44, height: 44).background(.white.opacity(0.06), in: Circle())
                    }.accessibilityLabel("Gesture guide")
                }
                pad.frame(maxWidth: .infinity, maxHeight: .infinity)
                clickDock
                HStack {
                    Image(systemName: "lock.shield").font(.system(size: 10))
                    Text(link.phase == .connected ? "PRIVATE CONNECTION" : "DESIGNED FOR YOUR MAC")
                        .font(.system(size: 9, weight: .medium, design: .monospaced)).tracking(1.3)
                    Spacer()
                    Text("PALMPAD / 01").font(.system(size: 9, design: .monospaced)).tracking(1)
                }.foregroundStyle(.white.opacity(0.32))
            }
            .padding(.horizontal, 24).padding(.top, 12).padding(.bottom, 12)
        }
        .background(padBackground).foregroundStyle(.white)
        .sheet(isPresented: $connections) { ConnectionSheet(link: link) }
        .sheet(isPresented: $settings) { SettingsSheet(model: model) }
        .sheet(isPresented: $help) { GestureGuide() }
        .onChange(of: link.phase) { _, phase in
            if phase == .connected { connections = false }
            if phase != .connected { contact = nil; fingerCount = 0 }
        }
    }

    private var header: some View {
        HStack(spacing: 9) {
            Image(systemName: "hand.draw.fill").font(.system(size: 20)).foregroundStyle(mint)
            Text("PalmPad").font(.system(size: 19, weight: .semibold, design: .rounded)).tracking(-0.4)
            Spacer()
            Button { connections = true } label: {
                HStack(spacing: 6) {
                    Circle().fill(link.phase == .connected ? mint : .white.opacity(0.4)).frame(width: 6, height: 6)
                    Text(link.phase == .connected ? "Connected" : "Connect").font(.system(size: 11, weight: .medium))
                }.padding(.horizontal, 12).frame(height: 44).background(.white.opacity(0.05), in: Capsule())
            }.accessibilityLabel(link.phase == .connected ? "Connected to \(link.peerName). Connection settings" : "Connect to your Mac")
            Button { settings = true } label: {
                Image(systemName: "slider.horizontal.3").font(.system(size: 18)).frame(width: 44, height: 44)
            }.accessibilityLabel("Trackpad settings")
        }
    }

    private var pad: some View {
        GeometryReader { proxy in
            ZStack {
                RoundedRectangle(cornerRadius: 30).fill(LinearGradient(
                    colors: [Color(red: 0.16, green: 0.20, blue: 0.18), Color(red: 0.11, green: 0.14, blue: 0.13)],
                    startPoint: .topLeading, endPoint: .bottomTrailing))
                Canvas { context, size in
                    for x in stride(from: 22.0, through: size.width, by: 20) {
                        for y in stride(from: 22.0, through: size.height, by: 20) {
                            context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 1.5, height: 1.5)), with: .color(.white.opacity(0.085)))
                        }
                    }
                }.clipShape(RoundedRectangle(cornerRadius: 30))
                VStack {
                    HStack {
                        Text(model.dragging ? "DRAGGING" : "TOUCH SURFACE")
                            .font(.system(size: 9, weight: .medium, design: .monospaced)).tracking(1.8)
                        Spacer()
                        Image(systemName: model.dragging ? "hand.point.up.left.fill" : "viewfinder")
                    }.foregroundStyle(model.dragging ? mint : .white.opacity(0.28))
                    Spacer()
                    if link.phase == .connected {
                        VStack(spacing: 12) {
                            Image(systemName: "hand.draw").font(.system(size: 44, weight: .ultraLight))
                            Text(model.dragging ? "Lift to release" : "Room to move.")
                                .font(.system(size: 16, weight: .light, design: .rounded))
                        }.foregroundStyle(.white.opacity(contact == nil ? 0.32 : 0.1))
                    }
                    Spacer()
                    HStack {
                        Text("1 FINGER · MOVE"); Spacer(); Text("2 FINGERS · SCROLL")
                    }.font(.system(size: 8, weight: .medium, design: .monospaced)).tracking(0.5).foregroundStyle(.white.opacity(0.24))
                }.padding(23).allowsHitTesting(false)
                if let contact {
                    Circle().fill(mint.opacity(0.06)).frame(width: 74, height: 74)
                        .overlay(Circle().stroke(mint.opacity(0.35), lineWidth: 1))
                        .overlay(Circle().fill(mint.opacity(0.65)).frame(width: 5, height: 5))
                        .position(contact).allowsHitTesting(false)
                    if fingerCount == 2 {
                        Image(systemName: "arrow.up.arrow.down").font(.system(size: 12)).foregroundStyle(mint)
                            .position(x: contact.x + 48, y: contact.y).allowsHitTesting(false)
                    }
                }
                TrackpadSurface(enabled: link.phase == .connected,
                    onCommand: model.command,
                    onContact: { point, count in contact = point; fingerCount = count })
                if link.phase != .connected {
                    VStack(spacing: 14) {
                        Image(systemName: "laptopcomputer.and.iphone").font(.system(size: 38, weight: .light)).foregroundStyle(mint)
                        Text("Meet your new trackpad.").font(.system(size: 18, weight: .medium, design: .rounded))
                        Text("Open PalmPad on your Mac,\nthen connect here.")
                            .font(.system(size: 12)).multilineTextAlignment(.center).foregroundStyle(.white.opacity(0.5))
                        Button { connections = true } label: {
                            Label("Find my Mac", systemImage: "arrow.up.right").font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(padBackground).padding(.horizontal, 21).frame(height: 46).background(mint, in: Capsule())
                        }
                    }.padding(12)
                }
            }
            .overlay(RoundedRectangle(cornerRadius: 30).stroke(model.dragging ? mint.opacity(0.5) : .white.opacity(0.10)))
            .clipShape(RoundedRectangle(cornerRadius: 30))
        }.frame(minHeight: 200)
    }

    private var clickDock: some View {
        VStack(spacing: 13) {
            HStack(spacing: 10) {
                clickButton("Left click", symbol: "cursorarrow", command: PadCommand(kind: .click), prominent: true)
                clickButton("Double", symbol: "cursorarrow.click.2", command: PadCommand(kind: .doubleClick))
                clickButton("Right click", symbol: "contextualmenu.and.cursorarrow", command: PadCommand(kind: .click, button: .right))
            }.disabled(link.phase != .connected).opacity(link.phase == .connected ? 1 : 0.45)
            Text("Tap to click · Hold, then move to drag").font(.system(size: 11)).foregroundStyle(.white.opacity(0.4))
        }
    }

    private func clickButton(_ title: String, symbol: String, command: PadCommand, prominent: Bool = false) -> some View {
        Button { model.command(command) } label: {
            VStack(spacing: 8) {
                Image(systemName: symbol).font(.system(size: 19, weight: .regular))
                Text(title).font(.system(size: 11, weight: .medium))
            }.frame(maxWidth: .infinity).frame(height: 76)
                .foregroundStyle(prominent ? padBackground : .white.opacity(0.8))
                .background(prominent ? mint : .white.opacity(0.06), in: RoundedRectangle(cornerRadius: 20))
        }.buttonStyle(.plain).accessibilityLabel(title == "Double" ? "Double-click" : title)
    }
}

private struct ConnectionSheet: View {
    @ObservedObject var link: PeerLink
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 24) {
                Text(link.phase == .connected ? "You’re connected." : "A nearby connection.")
                    .font(.system(size: 29, weight: .medium, design: .rounded)).tracking(-0.8)
                Text(link.status).font(.system(size: 15)).foregroundStyle(.secondary)
                if link.phase == .verifying {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(link.safetyNumber).font(.system(size: 42, weight: .medium, design: .monospaced)).tracking(6)
                            .foregroundStyle(mint).minimumScaleFactor(0.7).lineLimit(1)
                            .accessibilityLabel("Pairing code \(link.safetyNumber.map(String.init).joined(separator: " "))")
                        Text("Check that \(link.peerName) shows the same six digits, then choose “Codes match · Allow” on your Mac.")
                            .font(.system(size: 14)).foregroundStyle(.secondary)
                    }.padding(22).frame(maxWidth: .infinity, alignment: .leading).background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 22))
                } else if link.phase == .discovering {
                    if link.nearby.isEmpty {
                        HStack(spacing: 12) { ProgressView(); Text("Searching for Macs…").font(.system(size: 14)) }
                        Text("On your Mac, open PalmPad and click Start pairing. Keep both devices awake, with Wi-Fi and Bluetooth enabled.")
                            .font(.system(size: 14)).foregroundStyle(.secondary)
                    }
                    ForEach(link.nearby, id: \.self) { peer in
                        Button { link.connect(to: peer) } label: {
                            HStack(spacing: 14) {
                                Image(systemName: "laptopcomputer").font(.system(size: 25)).foregroundStyle(mint)
                                Text(peer.displayName).font(.system(size: 16, weight: .medium))
                                Spacer()
                                Image(systemName: "arrow.up.right").foregroundStyle(mint)
                            }.padding(20).background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 18))
                        }.buttonStyle(.plain)
                    }
                } else if link.phase == .connecting { ProgressView("Creating a secure connection…") }
                else if link.phase == .connected {
                    Label(link.peerName, systemImage: "checkmark.shield.fill").foregroundStyle(mint)
                    Button("Back to trackpad") { dismiss() }.buttonStyle(.borderedProminent).tint(mint).foregroundStyle(padBackground)
                }
                Spacer()
                if link.phase == .idle {
                    Button("Search again") { link.start() }.buttonStyle(.borderedProminent).tint(mint).foregroundStyle(padBackground)
                } else {
                    Button(link.phase == .connected ? "Disconnect" : "Cancel connection", role: .destructive) { link.disconnect() }
                }
                Text("No account. No cloud relay. Approve each new session on your Mac.")
                    .font(.system(size: 12)).foregroundStyle(.secondary)
            }.padding(26).frame(maxWidth: .infinity, alignment: .leading).background(padBackground)
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() }.tint(mint) } }
        }.onAppear { if link.phase == .idle { link.start() } }
    }
}

private struct SettingsSheet: View {
    @ObservedObject var model: PhoneModel
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            Form {
                Section("Pointer") {
                    HStack { Text("Speed"); Spacer(); Text(String(format: "%.1f×", model.pointerSpeed)).foregroundStyle(.secondary) }
                    Slider(value: $model.pointerSpeed, in: 0.5...4, step: 0.1).accessibilityLabel("Pointer speed")
                }
                Section("Scrolling") {
                    HStack { Text("Speed"); Spacer(); Text(String(format: "%.1f×", model.scrollSpeed)).foregroundStyle(.secondary) }
                    Slider(value: $model.scrollSpeed, in: 0.5...3, step: 0.1) { Text("Scroll speed") }
                    Toggle("Natural scrolling", isOn: $model.naturalScroll)
                }
                Section {
                    Toggle("Haptic clicks", isOn: $model.hapticsEnabled)
                    HStack { Text("Strength"); Spacer(); Text(model.hapticIntensity, format: .percent.precision(.fractionLength(0))).foregroundStyle(.secondary) }
                    Slider(value: $model.hapticIntensity, in: 0.2...1, step: 0.1, onEditingChanged: { editing in if !editing { model.feedback() } }) { Text("Haptic strength") }
                        .disabled(!model.hapticsEnabled)
                    Button("Try a click") { model.feedback() }.disabled(!model.hapticsEnabled)
                } header: { Text("Feel") } footer: {
                    Text("Crisp feedback for clicks and dragging. The iPhone’s haptic engine feels different from a MacBook’s Force Touch trackpad.")
                }
                Section {
                    Toggle("Keep screen awake while connected", isOn: $model.keepAwake)
                        .onChange(of: model.keepAwake) { _, value in UIApplication.shared.isIdleTimerDisabled = value && model.link.phase == .connected }
                } footer: { Text("Leaving the app disconnects the session and releases any held mouse button.") }
            }.tint(mint).navigationTitle("Make it yours")
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }
    }
}

private struct GestureGuide: View {
    @Environment(\.dismiss) private var dismiss
    private let gestures: [(String, String, String)] = [
        ("hand.point.up.left", "Move", "Slide one finger across the touch surface."),
        ("cursorarrow.click", "Left click", "Tap once. Tap twice quickly to double-click."),
        ("hand.tap", "Right click", "Tap with two fingers, or use the Right click button."),
        ("arrow.up.arrow.down", "Scroll", "Slide two fingers vertically or horizontally."),
        ("hand.draw", "Drag & select", "Hold one finger still until you feel a click, then move. Lift to release.")
    ]
    var body: some View {
        NavigationStack {
            List(gestures, id: \.1) { item in
                HStack(alignment: .top, spacing: 18) {
                    Image(systemName: item.0).font(.system(size: 24)).foregroundStyle(mint).frame(width: 30)
                    VStack(alignment: .leading, spacing: 5) {
                        Text(item.1).font(.headline)
                        Text(item.2).font(.subheadline).foregroundStyle(.secondary)
                    }
                }.padding(.vertical, 12)
            }.navigationTitle("A few simple gestures")
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() }.tint(mint) } }
        }
    }
}
