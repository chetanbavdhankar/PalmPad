import SwiftUI
import UIKit
import Combine

final class PhoneModel: NSObject, ObservableObject {
    let link = PeerLink(role: .controller, name: UIDevice.current.name)
    @Published var dragging = false
    @Published var pointerSpeed = Preference.number("pointerSpeed", fallback: 1.7, range: 0.5...4) {
        didSet { UserDefaults.standard.set(pointerSpeed, forKey: "pointerSpeed") }
    }
    @Published var scrollSpeed = Preference.number("scrollSpeed", fallback: 1.3, range: 0.5...3) {
        didSet { UserDefaults.standard.set(scrollSpeed, forKey: "scrollSpeed") }
    }
    @Published var naturalScroll = Preference.flag("naturalScroll", fallback: true) {
        didSet { UserDefaults.standard.set(naturalScroll, forKey: "naturalScroll") }
    }
    @Published var hapticsEnabled = Preference.flag("hapticsEnabled", fallback: true) {
        didSet { UserDefaults.standard.set(hapticsEnabled, forKey: "hapticsEnabled") }
    }
    @Published var hapticIntensity = Preference.number("hapticIntensity", fallback: 0.7, range: 0.2...1) {
        didSet { UserDefaults.standard.set(hapticIntensity, forKey: "hapticIntensity") }
    }
    @Published var keepAwake = Preference.flag("keepAwake", fallback: true) {
        didSet { UserDefaults.standard.set(keepAwake, forKey: "keepAwake") }
    }

    private let impact = UIImpactFeedbackGenerator(style: .rigid)
    private let selection = UISelectionFeedbackGenerator()
    private var displayLink: CADisplayLink?
    private var pending: PadCommand?
    private var phaseSubscription: AnyCancellable?

    override init() {
        super.init()
        link.onDisconnect = { [weak self] in self?.pending = nil; self?.dragging = false }
        phaseSubscription = link.$phase.sink { [weak self] phase in
            guard let self else { return }
            UIApplication.shared.isIdleTimerDisabled = phase == .connected && self.keepAwake
            if phase == .connected { self.startFrames(); self.feedback() }
            else { self.displayLink?.invalidate(); self.displayLink = nil; self.pending = nil }
        }
    }

    func command(_ command: PadCommand) {
        guard link.phase == .connected else { return }
        var command = command
        if command.kind == .move || command.kind == .scroll {
            let gain = command.kind == .move ? pointerSpeed : scrollSpeed * (naturalScroll ? 1 : -1)
            command.x = min(500, max(-500, command.x * gain))
            command.y = min(500, max(-500, command.y * gain))
            if var buffered = pending, buffered.kind == command.kind {
                buffered.x = min(2_000, max(-2_000, buffered.x + command.x))
                buffered.y = min(2_000, max(-2_000, buffered.y + command.y))
                pending = buffered
            } else { flush(); pending = command }
            return
        }
        flush() // Preserve movement/button ordering across the reliable stream.
        link.send(command)
        switch command.kind {
        case .buttonDown: dragging = true; feedback()
        case .buttonUp: dragging = false; if hapticsEnabled { selection.selectionChanged() }
        case .click, .doubleClick: feedback()
        default: break
        }
    }

    func feedback() {
        guard hapticsEnabled else { return }
        impact.impactOccurred(intensity: hapticIntensity)
        impact.prepare()
    }

    func suspend() {
        flush()
        link.send(PadCommand(kind: .releaseAll))
        link.disconnect(reason: "Paused while PalmPad is in the background. Reconnect to continue.")
        UIApplication.shared.isIdleTimerDisabled = false
    }

    private func startFrames() {
        displayLink?.invalidate()
        let frames = CADisplayLink(target: self, selector: #selector(flush))
        frames.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 60, preferred: 60)
        frames.add(to: .main, forMode: .common)
        displayLink = frames
        impact.prepare()
    }

    @objc private func flush() {
        if let pending { link.send(pending) }
        pending = nil
    }
}

private enum Preference {
    static func flag(_ key: String, fallback: Bool) -> Bool {
        UserDefaults.standard.object(forKey: key) as? Bool ?? fallback
    }
    static func number(_ key: String, fallback: Double, range: ClosedRange<Double>) -> Double {
        guard let value = UserDefaults.standard.object(forKey: key) as? Double, value.isFinite else { return fallback }
        return min(range.upperBound, max(range.lowerBound, value))
    }
}
