import Foundation

struct Contact: Equatable {
    var id: Int
    var x: Double
    var y: Double
}

/// Pure gesture state machine; UIKit only supplies contacts and timestamps.
struct GestureMachine {
    private var previous: [Contact] = []
    private var origins: [Int: Contact] = [:]
    private var started: TimeInterval = 0
    private var maxFingers = 0
    private var traveled: Double = 0
    private var suppressed = false
    private var lifting = false
    private(set) var dragging = false
    private var lastTap: (time: TimeInterval, x: Double, y: Double)?
    var holdDuration: TimeInterval = 0.45
    var tapSlop: Double = 8

    mutating func update(_ contacts: [Contact], at time: TimeInterval) -> [PadCommand] {
        var output: [PadCommand] = []
        if previous.isEmpty, !contacts.isEmpty {
            started = time
            maxFingers = 0
            traveled = 0
            suppressed = false
            lifting = false
            origins = [:]
        }
        for contact in contacts {
            if origins[contact.id] == nil { origins[contact.id] = contact }
            if let start = origins[contact.id] {
                traveled = max(traveled, hypot(contact.x - start.x, contact.y - start.y))
            }
        }
        maxFingers = max(maxFingers, contacts.count)
        if maxFingers > 2 { suppressed = true }
        if dragging, contacts.count != 1 {
            output.append(PadCommand(kind: .buttonUp))
            dragging = false
            suppressed = true
        }
        if contacts.isEmpty, !previous.isEmpty {
            if dragging {
                output.append(PadCommand(kind: .buttonUp))
            } else if !suppressed, traveled <= tapSlop, time - started < holdDuration {
                if maxFingers == 2 {
                    output.append(PadCommand(kind: .click, button: .right))
                    lastTap = nil
                } else if maxFingers == 1, let origin = origins.values.first {
                    let double = lastTap.map { time - $0.time < 0.35 && hypot(origin.x - $0.x, origin.y - $0.y) < 30 } ?? false
                    output.append(PadCommand(kind: .click, clickCount: double ? 2 : 1))
                    lastTap = double ? nil : (time, origin.x, origin.y)
                }
            } else { lastTap = nil }
            dragging = false
            previous = []
            return output
        }
        // Ignore the remaining finger after scrolling; lifting one finger must not move the cursor.
        if contacts.count < previous.count, !contacts.isEmpty { lifting = true }
        if !suppressed, !lifting, contacts.count == previous.count, !contacts.isEmpty,
           Set(contacts.map(\.id)) == Set(previous.map(\.id)) {
            let x = (contacts.reduce(0) { $0 + $1.x } - previous.reduce(0) { $0 + $1.x }) / Double(contacts.count)
            let y = (contacts.reduce(0) { $0 + $1.y } - previous.reduce(0) { $0 + $1.y }) / Double(contacts.count)
            if x != 0 || y != 0 {
                if contacts.count == 1 {
                    output.append(PadCommand(kind: .move, x: x, y: y))
                } else if contacts.count == 2, traveled > tapSlop {
                    output.append(PadCommand(kind: .scroll, x: x, y: y))
                }
            }
        }
        previous = contacts
        return output
    }

    mutating func advance(to time: TimeInterval) -> [PadCommand] {
        guard previous.count == 1, maxFingers == 1, !dragging, !suppressed, !lifting,
              traveled <= tapSlop, time - started >= holdDuration else { return [] }
        dragging = true
        lastTap = nil
        return [PadCommand(kind: .buttonDown)]
    }

    mutating func cancel() -> [PadCommand] {
        let output = dragging ? [PadCommand(kind: .buttonUp)] : []
        self = GestureMachine()
        return output
    }
}
