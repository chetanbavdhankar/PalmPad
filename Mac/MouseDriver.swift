import AppKit
import ApplicationServices

final class MouseDriver {
    private let source = CGEventSource(stateID: .hidSystemState)
    private(set) var held = Set<MouseButton>()

    static var hasPermission: Bool { AXIsProcessTrusted() }

    static func requestPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    func handle(_ command: PadCommand) {
        guard command.isValid, Self.hasPermission else { releaseAll(); return }
        switch command.kind {
        case .move:
            guard let current = CGEvent(source: nil)?.location else { return }
            let desired = CGPoint(x: current.x + command.x, y: current.y + command.y)
            let position = clampedToDisplays(desired)
            let type: CGEventType = held.contains(.left) ? .leftMouseDragged : (held.contains(.right) ? .rightMouseDragged : .mouseMoved)
            let event = CGEvent(mouseEventSource: source, mouseType: type, mouseCursorPosition: position,
                                mouseButton: held.contains(.right) ? .right : .left)
            event?.setIntegerValueField(.mouseEventDeltaX, value: Int64((position.x - current.x).rounded()))
            event?.setIntegerValueField(.mouseEventDeltaY, value: Int64((position.y - current.y).rounded()))
            event?.post(tap: .cghidEventTap)
        case .scroll:
            let event = CGEvent(scrollWheelEvent2Source: source, units: .pixel, wheelCount: 2,
                                wheel1: Int32(command.y.rounded()), wheel2: Int32(command.x.rounded()), wheel3: 0)
            event?.post(tap: .cghidEventTap)
        case .click:
            guard held.isEmpty else { return }
            button(command.button, down: true, count: command.clickCount)
            button(command.button, down: false, count: command.clickCount)
        case .doubleClick:
            guard held.isEmpty else { return }
            for count in 1...2 {
                button(.left, down: true, count: count)
                button(.left, down: false, count: count)
            }
        case .buttonDown:
            guard !held.contains(command.button) else { return }
            button(command.button, down: true)
        case .buttonUp:
            guard held.contains(command.button) else { return }
            button(command.button, down: false)
        case .releaseAll: releaseAll()
        default: break
        }
    }

    func releaseAll() {
        for button in Array(held) { self.button(button, down: false) }
    }

    private func button(_ button: MouseButton, down: Bool, count: Int = 1) {
        guard let position = CGEvent(source: nil)?.location else { return }
        let type: CGEventType = button == .left ? (down ? .leftMouseDown : .leftMouseUp) : (down ? .rightMouseDown : .rightMouseUp)
        let event = CGEvent(mouseEventSource: source, mouseType: type, mouseCursorPosition: position,
                            mouseButton: button == .left ? .left : .right)
        event?.setIntegerValueField(.mouseEventClickState, value: Int64(count))
        event?.post(tap: .cghidEventTap)
        if down { held.insert(button) } else { held.remove(button) }
    }

    private func clampedToDisplays(_ point: CGPoint) -> CGPoint {
        var ids = [CGDirectDisplayID](repeating: 0, count: 32)
        var count: UInt32 = 0
        guard CGGetActiveDisplayList(32, &ids, &count) == .success else { return point }
        let rectangles = ids.prefix(Int(count)).map { CGDisplayBounds($0) }
        if rectangles.contains(where: { $0.contains(point) }) { return point }
        return rectangles.map { rect in
            CGPoint(x: min(max(point.x, rect.minX), rect.maxX - 1), y: min(max(point.y, rect.minY), rect.maxY - 1))
        }.min { hypot($0.x - point.x, $0.y - point.y) < hypot($1.x - point.x, $1.y - point.y) } ?? point
    }
}
