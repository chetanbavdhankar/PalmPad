import XCTest
@testable import PalmPadCore

final class SecurityTests: XCTestCase {
    private func pair() throws -> (SessionCipher, SessionCipher) {
        let host = SessionCipher(), phone = SessionCipher()
        try host.accept(phone.publicKey, isHost: true)
        try phone.accept(host.publicKey, isHost: false)
        return (host, phone)
    }

    func testMatchingSafetyNumbersAndEncryptedRoundTrip() throws {
        let (host, phone) = try pair()
        XCTAssertEqual(host.safetyNumber, phone.safetyNumber)
        XCTAssertEqual(host.safetyNumber?.count, 6)
        let click = PadCommand(kind: .click, button: .right)
        XCTAssertEqual(try host.open(phone.seal(click)), click)
        XCTAssertEqual(try phone.open(host.seal(PadCommand(kind: .approved))).kind, .approved)
    }

    func testUnpairedCannotSendOrReceive() throws {
        let cipher = SessionCipher()
        XCTAssertThrowsError(try cipher.seal(PadCommand(kind: .move)))
        XCTAssertThrowsError(try cipher.open(Data()))
    }

    func testReplayAndOldMessagesRejected() throws {
        let (host, phone) = try pair()
        let first = try phone.seal(PadCommand(kind: .buttonDown))
        let second = try phone.seal(PadCommand(kind: .buttonUp))
        XCTAssertEqual(try host.open(second).kind, .buttonUp)
        XCTAssertThrowsError(try host.open(first))
        XCTAssertThrowsError(try host.open(second))
    }

    func testTamperCannotChangeMouseInput() throws {
        let (host, phone) = try pair()
        var message = try phone.seal(PadCommand(kind: .move, x: 20))
        message[message.count - 1] ^= 0xff
        XCTAssertThrowsError(try host.open(message))
    }

    func testNewSessionRejectsOldCiphertext() throws {
        let (_, oldPhone) = try pair()
        let (newHost, _) = try pair()
        XCTAssertThrowsError(try newHost.open(oldPhone.seal(PadCommand(kind: .click))))
    }

    func testReflectionAndRepeatedKeyExchangeRejected() throws {
        let cipher = SessionCipher()
        XCTAssertThrowsError(try cipher.accept(cipher.publicKey, isHost: true))
        XCTAssertThrowsError(try cipher.accept(Data([1, 2]), isHost: true))
        let (host, phone) = try pair()
        XCTAssertThrowsError(try host.accept(phone.publicKey, isHost: true))
        XCTAssertThrowsError(try host.open(host.seal(PadCommand(kind: .approved))))
    }

    func testOversizedAndInvalidInputsRejected() throws {
        let (host, phone) = try pair()
        XCTAssertThrowsError(try host.open(Data(repeating: 0, count: 2_049)))
        XCTAssertThrowsError(try phone.seal(PadCommand(kind: .move, x: .infinity)))
        XCTAssertThrowsError(try phone.seal(PadCommand(kind: .move, x: .nan)))
        XCTAssertThrowsError(try phone.seal(PadCommand(kind: .move, x: 2_001)))
        XCTAssertThrowsError(try phone.seal(PadCommand(kind: .click, clickCount: 99)))
    }
}

final class GestureTests: XCTestCase {
    private func finger(_ id: Int = 1, _ x: Double = 20, _ y: Double = 20) -> Contact {
        Contact(id: id, x: x, y: y)
    }
    func testSingleAndDoubleTapHaveNativeClickCounts() {
        var g = GestureMachine()
        XCTAssertTrue(g.update([finger()], at: 0).isEmpty)
        XCTAssertEqual(g.update([], at: 0.08), [PadCommand(kind: .click)])
        _ = g.update([finger()], at: 0.15)
        XCTAssertEqual(g.update([], at: 0.23), [PadCommand(kind: .click, clickCount: 2)])
    }

    func testSlowOrDistantSecondTapIsSingle() {
        var g = GestureMachine()
        _ = g.update([finger()], at: 0)
        _ = g.update([], at: 0.05)
        _ = g.update([finger(1, 100, 100)], at: 0.15)
        XCTAssertEqual(g.update([], at: 0.2).first?.clickCount, 1)
        _ = g.update([finger(1, 100, 100)], at: 1)
        XCTAssertEqual(g.update([], at: 1.1).first?.clickCount, 1)
    }

    func testMovementIsRelativeAndDoesNotClick() {
        var g = GestureMachine()
        _ = g.update([finger()], at: 0)
        XCTAssertEqual(g.update([finger(1, 50, 35)], at: 0.1), [PadCommand(kind: .move, x: 30, y: 15)])
        XCTAssertTrue(g.update([], at: 0.2).isEmpty)
    }

    func testTwoFingerTapWithStaggeredLiftRightClicksOnce() {
        var g = GestureMachine()
        _ = g.update([finger()], at: 0)
        _ = g.update([finger(), finger(2, 60, 20)], at: 0.02)
        XCTAssertTrue(g.update([finger()], at: 0.09).isEmpty)
        XCTAssertEqual(g.update([], at: 0.11), [PadCommand(kind: .click, button: .right)])
    }

    func testTwoFingerScrollAndTailDoNotMoveOrClick() {
        var g = GestureMachine()
        _ = g.update([finger(), finger(2, 60, 20)], at: 0)
        XCTAssertEqual(g.update([finger(1, 25, 40), finger(2, 65, 40)], at: 0.1), [PadCommand(kind: .scroll, x: 5, y: 20)])
        XCTAssertTrue(g.update([finger(1, 25, 40)], at: 0.12).isEmpty)
        XCTAssertTrue(g.update([finger(1, 45, 60)], at: 0.15).isEmpty)
        XCTAssertTrue(g.update([], at: 0.2).isEmpty)
    }

    func testHoldDragAndLiftRelease() {
        var g = GestureMachine()
        _ = g.update([finger()], at: 0)
        XCTAssertTrue(g.advance(to: 0.3).isEmpty)
        XCTAssertEqual(g.advance(to: 0.46), [PadCommand(kind: .buttonDown)])
        XCTAssertTrue(g.advance(to: 0.6).isEmpty)
        XCTAssertEqual(g.update([finger(1, 45, 20)], at: 0.7).first?.kind, .move)
        XCTAssertEqual(g.update([], at: 0.9), [PadCommand(kind: .buttonUp)])
        XCTAssertFalse(g.dragging)
    }

    func testCancellationAndSecondFingerReleaseDrag() {
        var g = GestureMachine()
        _ = g.update([finger()], at: 0)
        _ = g.advance(to: 0.46)
        XCTAssertEqual(g.cancel(), [PadCommand(kind: .buttonUp)])
        XCTAssertTrue(g.cancel().isEmpty)
        _ = g.update([finger()], at: 1)
        _ = g.advance(to: 1.46)
        XCTAssertEqual(g.update([finger(), finger(2)], at: 1.5), [PadCommand(kind: .buttonUp)])
        XCTAssertTrue(g.update([], at: 1.6).isEmpty)
    }

    func testMovementCancelsLongPressAndThirdFingerSuppresses() {
        var g = GestureMachine()
        _ = g.update([finger()], at: 0)
        _ = g.update([finger(1, 40, 20)], at: 0.1)
        XCTAssertTrue(g.advance(to: 0.6).isEmpty)
        _ = g.cancel()
        _ = g.update([finger(), finger(2), finger(3)], at: 1)
        XCTAssertTrue(g.update([], at: 1.1).isEmpty)
    }
}
