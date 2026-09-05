import SwiftUI
import AppKit

final class MacModel: ObservableObject {
    let link = PeerLink(role: .host, name: Host.current().localizedName ?? "My Mac")
    let mouse = MouseDriver()
    @Published var hasPermission = MouseDriver.hasPermission
    private var permissionTimer: Timer?
    private var observers: [NSObjectProtocol] = []
    private var lockObserver: NSObjectProtocol?

    init() {
        link.onCommand = { [weak self] command in self?.mouse.handle(command) }
        link.onDisconnect = { [weak self] in self?.mouse.releaseAll() }
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            let allowed = MouseDriver.hasPermission
            if self.hasPermission != allowed {
                self.hasPermission = allowed
                if !allowed { self.link.disconnect(reason: "Accessibility access was removed.") }
            }
        }
        for name in [NSWorkspace.willSleepNotification, NSWorkspace.screensDidSleepNotification,
                     NSWorkspace.sessionDidResignActiveNotification] {
            observers.append(NSWorkspace.shared.notificationCenter.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.link.disconnect(reason: "Mac went to sleep or locked. Start pairing again to reconnect.")
            })
        }
        lockObserver = DistributedNotificationCenter.default().addObserver(forName: NSNotification.Name("com.apple.screenIsLocked"), object: nil, queue: .main) { [weak self] _ in
            self?.link.disconnect(reason: "Mac is locked. Start pairing again after unlocking.")
        }
        NotificationCenter.default.addObserver(forName: NSApplication.willTerminateNotification, object: nil, queue: .main) { [weak self] _ in
            self?.mouse.releaseAll()
        }
    }
}

@main
struct PalmPadMacApp: App {
    @StateObject private var model = MacModel()
    var body: some Scene {
        WindowGroup("PalmPad", id: "main") {
            MacHome(model: model, link: model.link)
                .frame(width: 520, height: 650)
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)
        MenuBarExtra("PalmPad", systemImage: "hand.draw") {
            MacMenu(model: model, link: model.link)
        }
    }
}

private struct MacMenu: View {
    @ObservedObject var model: MacModel
    @ObservedObject var link: PeerLink
    @Environment(\.openWindow) private var openWindow
    var body: some View {
        Text(link.status)
        Button("Open PalmPad") { openWindow(id: "main"); NSApp.activate(ignoringOtherApps: true) }
        Divider()
        if link.phase != .idle {
            Button("Disconnect & stop pairing") { link.disconnect() }
        } else {
            Button("Start pairing") { link.start(); openWindow(id: "main") }.disabled(!model.hasPermission)
        }
        Divider()
        Button("Quit PalmPad") { model.mouse.releaseAll(); NSApp.terminate(nil) }.keyboardShortcut("q")
    }
}

private struct MacHome: View {
    @ObservedObject var model: MacModel
    @ObservedObject var link: PeerLink
    private let ink = Color(red: 0.13, green: 0.20, blue: 0.18)
    private let green = Color(red: 0.15, green: 0.42, blue: 0.32)

    var body: some View {
        VStack(alignment: .leading, spacing: 26) {
            HStack(spacing: 12) {
                Image(systemName: "hand.draw.fill").font(.system(size: 25)).foregroundStyle(green)
                    .frame(width: 52, height: 52).background(green.opacity(0.09), in: RoundedRectangle(cornerRadius: 16))
                VStack(alignment: .leading, spacing: 2) {
                    Text("PalmPad").font(.system(size: 25, weight: .semibold, design: .rounded))
                    Text("A little closer to your Mac.").font(.system(size: 12)).foregroundStyle(.secondary)
                }
                Spacer()
                Text("MAC COMPANION").font(.system(size: 9, weight: .bold, design: .monospaced)).tracking(1.2).foregroundStyle(green)
            }

            VStack(alignment: .leading, spacing: 12) {
                Text(link.phase == .connected ? "Your Mac.\nAt your fingertips." : "Your iPhone.\nYour new trackpad.")
                    .font(.system(size: 38, weight: .medium, design: .rounded)).tracking(-1.5)
                Text("Move, click, scroll, and select — from the comfort of your phone.")
                    .font(.system(size: 14)).foregroundStyle(.secondary).lineSpacing(3)
            }

            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: model.hasPermission ? "checkmark.shield.fill" : "lock.open")
                        .foregroundStyle(model.hasPermission ? green : .orange)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(model.hasPermission ? "Mouse control is ready" : "Allow mouse control").font(.system(size: 14, weight: .semibold))
                        Text(model.hasPermission ? "Accessibility access enabled" : "Enable PalmPad Mac in Accessibility settings.")
                            .font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if !model.hasPermission {
                        Button("Open Settings", action: MouseDriver.requestPermission).buttonStyle(.bordered)
                    }
                }
                Divider()
                connectionPanel
            }
            .padding(22).frame(maxWidth: .infinity, alignment: .leading)
            .background(.white.opacity(0.7), in: RoundedRectangle(cornerRadius: 22))
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(ink.opacity(0.08)))
            Spacer(minLength: 0)
            HStack(spacing: 8) {
                Image(systemName: "lock.shield").foregroundStyle(green)
                Text("Encrypted. Nearby. No account needed.").font(.system(size: 11)).foregroundStyle(.secondary)
                Spacer()
                Text("01 / PALMPAD").font(.system(size: 9, design: .monospaced)).foregroundStyle(.tertiary)
            }
        }
        .padding(32).foregroundStyle(ink)
        .background(Color(red: 0.96, green: 0.96, blue: 0.92))
        .preferredColorScheme(.light)
    }

    @ViewBuilder private var connectionPanel: some View {
        switch link.phase {
        case .verifying:
            Text("Is this the code on your iPhone?").font(.system(size: 15, weight: .semibold))
            Text(link.safetyNumber).font(.system(size: 38, weight: .medium, design: .monospaced)).tracking(9)
                .accessibilityLabel("Pairing code \(link.safetyNumber.map(String.init).joined(separator: " "))")
            Text("\(link.peerName) wants to control this Mac. Approve only if both codes match.")
                .font(.system(size: 12)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            HStack {
                Button("Codes match · Allow") { if model.hasPermission { link.approve() } }
                    .buttonStyle(.borderedProminent).tint(green).disabled(!model.hasPermission)
                Button("Reject") { link.disconnect(reason: "Pairing rejected.") }.buttonStyle(.bordered)
            }
        case .connected:
            Label("Connected to \(link.peerName)", systemImage: "iphone.radiowaves.left.and.right")
                .font(.system(size: 15, weight: .semibold)).foregroundStyle(green)
            Text("You can close this window. PalmPad stays in your menu bar.")
                .font(.system(size: 12)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Button("Disconnect iPhone") { link.disconnect() }.buttonStyle(.bordered)
        case .discovering, .connecting:
            HStack(spacing: 12) {
                ProgressView().controlSize(.small)
                Text(link.status).font(.system(size: 14, weight: .semibold))
            }
            Text("Keep Wi-Fi and Bluetooth on. Using the same Wi-Fi network is the easiest way to connect.")
                .font(.system(size: 12)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Button("Cancel") { link.disconnect() }.buttonStyle(.bordered)
        case .idle:
            Text("Connect your iPhone").font(.system(size: 16, weight: .semibold))
            Text(link.status).font(.system(size: 12)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Button { link.start() } label: {
                Label("Start pairing", systemImage: "plus.circle.fill").padding(.vertical, 5).frame(maxWidth: .infinity)
            }.buttonStyle(.borderedProminent).tint(green).disabled(!model.hasPermission)
        }
    }
}
