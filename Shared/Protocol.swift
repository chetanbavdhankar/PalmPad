import Foundation
import CryptoKit

enum MouseButton: String, Codable { case left, right }

enum CommandKind: String, Codable {
    case approved, ping, pong, move, scroll, click, doubleClick, buttonDown, buttonUp, releaseAll
}

struct PadCommand: Codable, Equatable {
    var kind: CommandKind
    var x: Double = 0
    var y: Double = 0
    var button: MouseButton = .left
    var clickCount: Int = 1

    var isValid: Bool {
        x.isFinite && y.isFinite && abs(x) <= 2_000 && abs(y) <= 2_000
            && (1...2).contains(clickCount)
    }
}

private struct SecureEnvelope: Codable {
    let version: Int
    let sequence: UInt64
    let command: PadCommand
}

struct Handshake: Codable {
    let version: Int
    let publicKey: Data
}

enum ProtocolError: Error { case invalidHandshake, notReady, invalidMessage, replay }

/// Ephemeral authenticated encryption. The six-digit safety number must be compared
/// on both devices before approving; discovery names are deliberately not trusted.
final class SessionCipher {
    private let privateKey = Curve25519.KeyAgreement.PrivateKey()
    private var sendKey: SymmetricKey?
    private var receiveKey: SymmetricKey?
    private var sent: UInt64 = 0
    private var received: UInt64 = 0
    private(set) var safetyNumber: String?
    var publicKey: Data { privateKey.publicKey.rawRepresentation }

    func accept(_ remoteKey: Data, isHost: Bool) throws {
        guard sendKey == nil, remoteKey.count == 32, remoteKey != publicKey else {
            throw ProtocolError.invalidHandshake
        }
        let remote = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: remoteKey)
        let secret = try privateKey.sharedSecretFromKeyAgreement(with: remote)
        let transcript = isHost ? publicKey + remoteKey : remoteKey + publicKey
        let salt = Data(SHA256.hash(data: transcript))
        func derive(_ label: String) -> SymmetricKey {
            secret.hkdfDerivedSymmetricKey(using: SHA256.self, salt: salt,
                sharedInfo: Data("PalmPad-v1-\(label)".utf8), outputByteCount: 32)
        }
        sendKey = derive(isHost ? "host-to-phone" : "phone-to-host")
        receiveKey = derive(isHost ? "phone-to-host" : "host-to-phone")
        let digest = Array(HMAC<SHA256>.authenticationCode(for: transcript, using: derive("verification")))
        let number = digest.prefix(4).reduce(UInt32(0)) { ($0 << 8) | UInt32($1) } % 1_000_000
        safetyNumber = String(format: "%06u", number)
    }

    func seal(_ command: PadCommand) throws -> Data {
        guard let sendKey else { throw ProtocolError.notReady }
        guard command.isValid, sent < UInt64.max else { throw ProtocolError.invalidMessage }
        sent += 1
        let data = try JSONEncoder().encode(SecureEnvelope(version: 1, sequence: sent, command: command))
        return try ChaChaPoly.seal(data, using: sendKey).combined
    }

    func open(_ data: Data) throws -> PadCommand {
        guard let receiveKey else { throw ProtocolError.notReady }
        guard data.count <= 2_048 else { throw ProtocolError.invalidMessage }
        let box = try ChaChaPoly.SealedBox(combined: data)
        let plaintext = try ChaChaPoly.open(box, using: receiveKey)
        let envelope = try JSONDecoder().decode(SecureEnvelope.self, from: plaintext)
        guard envelope.version == 1, envelope.command.isValid else { throw ProtocolError.invalidMessage }
        guard envelope.sequence > received else { throw ProtocolError.replay }
        received = envelope.sequence
        return envelope.command
    }
}
