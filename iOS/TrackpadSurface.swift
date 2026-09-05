import SwiftUI
import UIKit

struct TrackpadSurface: UIViewRepresentable {
    var enabled: Bool
    var onCommand: (PadCommand) -> Void
    var onContact: (CGPoint?, Int) -> Void

    func makeUIView(context: Context) -> TouchSurface {
        let view = TouchSurface()
        view.onCommand = onCommand
        view.onContact = onContact
        return view
    }
    func updateUIView(_ view: TouchSurface, context: Context) {
        view.onCommand = onCommand
        view.onContact = onContact
        if !enabled && view.isUserInteractionEnabled { view.cancelTouches() }
        view.isUserInteractionEnabled = enabled
    }
    static func dismantleUIView(_ view: TouchSurface, coordinator: ()) { view.cancelTouches() }
}

final class TouchSurface: UIView {
    var onCommand: ((PadCommand) -> Void)?
    var onContact: ((CGPoint?, Int) -> Void)?
    private var machine = GestureMachine()
    private var contacts: [Int: Contact] = [:]
    private var holdTimer: Timer?

    override init(frame: CGRect) {
        super.init(frame: frame)
        isMultipleTouchEnabled = true
        backgroundColor = .clear
        isAccessibilityElement = true
        accessibilityLabel = "Trackpad"
        accessibilityHint = "Move one finger to move the Mac pointer. Tap to click. Use two fingers to scroll or right-click. Hold, then move, to drag."
        accessibilityTraits = [.allowsDirectInteraction]
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        update(touches, removing: false)
        holdTimer?.invalidate()
        holdTimer = Timer.scheduledTimer(withTimeInterval: 0.46, repeats: false) { [weak self] _ in
            guard let self else { return }
            self.machine.advance(to: ProcessInfo.processInfo.systemUptime).forEach { self.onCommand?($0) }
        }
    }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) { update(touches, removing: false) }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) { update(touches, removing: true) }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) { cancelTouches() }
    override func didMoveToWindow() { if window == nil { cancelTouches() } }

    func cancelTouches() {
        holdTimer?.invalidate()
        holdTimer = nil
        guard !contacts.isEmpty || machine.dragging else { return }
        contacts = [:]
        machine.cancel().forEach { onCommand?($0) }
        onContact?(nil, 0)
    }

    private func update(_ touches: Set<UITouch>, removing: Bool) {
        for touch in touches {
            let id = ObjectIdentifier(touch).hashValue
            if removing { contacts.removeValue(forKey: id) }
            else {
                let position = touch.location(in: self)
                contacts[id] = Contact(id: id, x: position.x, y: position.y)
            }
        }
        machine.update(Array(contacts.values), at: ProcessInfo.processInfo.systemUptime).forEach { onCommand?($0) }
        if contacts.isEmpty {
            holdTimer?.invalidate()
            onContact?(nil, 0)
        } else {
            let count = Double(contacts.count)
            onContact?(CGPoint(x: contacts.values.reduce(0) { $0 + $1.x } / count,
                               y: contacts.values.reduce(0) { $0 + $1.y } / count), contacts.count)
        }
    }
}
