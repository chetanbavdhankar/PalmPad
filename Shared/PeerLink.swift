import Foundation
import Combine
import MultipeerConnectivity

enum LinkPhase: Equatable { case idle, discovering, connecting, verifying, connected }

/// All mutable state is confined to the main queue; delegate callbacks hop there.
final class PeerLink: NSObject, ObservableObject {
    enum Role { case host, controller }
    static let service = "palmpad-v1"
    let role: Role
    @Published private(set) var phase: LinkPhase = .idle
    @Published private(set) var nearby: [MCPeerID] = []
    @Published private(set) var peerName = ""
    @Published private(set) var safetyNumber = ""
    @Published private(set) var status = "Ready when you are"
    var onCommand: ((PadCommand) -> Void)?
    var onDisconnect: (() -> Void)?

    private let identity: MCPeerID
    private var session: MCSession!
    private var browser: MCNearbyServiceBrowser?
    private var advertiser: MCNearbyServiceAdvertiser?
    private var selected: MCPeerID?
    private var cipher = SessionCipher()
    private var heartbeat: Timer?
    private var started = Date()
    private var lastReceived = Date()
    private var helloSent = false

    init(role: Role, name: String) {
        self.role = role
        identity = MCPeerID(displayName: String(name.prefix(40)))
        super.init()
        makeSession()
    }

    private func makeSession() {
        session = MCSession(peer: identity, securityIdentity: nil, encryptionPreference: .required)
        session.delegate = self
        cipher = SessionCipher()
        helloSent = false
    }

    func start() {
        disconnect(reason: "Looking for a nearby \(role == .host ? "iPhone" : "Mac")")
        phase = .discovering
        if role == .host {
            let advertiser = MCNearbyServiceAdvertiser(peer: identity,
                discoveryInfo: ["role": "mac", "version": "1"], serviceType: Self.service)
            advertiser.delegate = self
            self.advertiser = advertiser
            advertiser.startAdvertisingPeer()
            status = "Open PalmPad on your iPhone"
        } else {
            let browser = MCNearbyServiceBrowser(peer: identity, serviceType: Self.service)
            browser.delegate = self
            self.browser = browser
            browser.startBrowsingForPeers()
            status = "Looking for your Mac…"
        }
    }

    func connect(to peer: MCPeerID) {
        guard role == .controller, phase == .discovering else { return }
        selected = peer
        peerName = peer.displayName
        phase = .connecting
        status = "Connecting securely…"
        beginHeartbeat()
        browser?.invitePeer(peer, to: session, withContext: Data("PalmPad-v1".utf8), timeout: 20)
    }

    func approve() {
        guard role == .host, phase == .verifying else { return }
        if sendInternal(PadCommand(kind: .approved)) {
            phase = .connected
            status = "\(peerName) is controlling this Mac"
        }
    }

    func send(_ command: PadCommand) {
        guard phase == .connected else { return }
        _ = sendInternal(command)
    }

    @discardableResult private func sendInternal(_ command: PadCommand) -> Bool {
        guard let selected, session.connectedPeers.contains(selected) else { return false }
        do {
            try session.send(cipher.seal(command), toPeers: [selected], with: .reliable)
            return true
        } catch {
            disconnect(reason: "Connection interrupted. Connect again.")
            return false
        }
    }

    func disconnect(reason: String = "Disconnected") {
        onDisconnect?()
        heartbeat?.invalidate()
        heartbeat = nil
        browser?.stopBrowsingForPeers()
        advertiser?.stopAdvertisingPeer()
        browser = nil
        advertiser = nil
        let oldSession = session
        oldSession?.delegate = nil
        oldSession?.disconnect()
        selected = nil
        safetyNumber = ""
        peerName = ""
        nearby = []
        phase = .idle
        status = reason
        makeSession()
    }

    private func beginHeartbeat() {
        started = Date()
        lastReceived = Date()
        heartbeat?.invalidate()
        heartbeat = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            if self.phase == .connecting, Date().timeIntervalSince(self.started) > 22 {
                self.disconnect(reason: "Connection timed out. Keep both devices awake and try again.")
            } else if self.phase == .verifying, Date().timeIntervalSince(self.started) > 60 {
                self.disconnect(reason: "Pairing expired. Connect again to get a new code.")
            } else if self.phase == .connected || self.phase == .verifying {
                if Date().timeIntervalSince(self.lastReceived) > 6 {
                    self.disconnect(reason: "Connection lost. Any held mouse button was released.")
                } else { self.sendInternal(PadCommand(kind: .ping)) }
            }
        }
    }

    private func received(_ data: Data, from peer: MCPeerID) {
        guard peer == selected, data.count <= 2_048 else { return }
        do {
            if phase == .connecting {
                let hello = try JSONDecoder().decode(Handshake.self, from: data)
                guard hello.version == 1 else { throw ProtocolError.invalidHandshake }
                try cipher.accept(hello.publicKey, isHost: role == .host)
                safetyNumber = cipher.safetyNumber ?? ""
                phase = .verifying
                status = role == .host ? "Compare this code with your iPhone" : "Compare the code, then approve on your Mac"
                lastReceived = Date()
                return
            }
            guard phase == .verifying || phase == .connected else { return }
            let command = try cipher.open(data)
            lastReceived = Date()
            switch command.kind {
            case .ping: sendInternal(PadCommand(kind: .pong))
            case .pong: break
            case .approved:
                guard role == .controller, phase == .verifying else { return }
                phase = .connected
                status = "Connected to \(peerName)"
            default:
                guard role == .host, phase == .connected else { return }
                onCommand?(command)
            }
        } catch { disconnect(reason: "Could not verify this connection. Please pair again.") }
    }
}

extension PeerLink: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        DispatchQueue.main.async { [weak self] in
            guard let self, session === self.session, peerID == self.selected else { return }
            switch state {
            case .connected:
                guard !self.helloSent else { return }
                self.helloSent = true
                self.browser?.stopBrowsingForPeers()
                self.advertiser?.stopAdvertisingPeer()
                do {
                    let data = try JSONEncoder().encode(Handshake(version: 1, publicKey: self.cipher.publicKey))
                    try session.send(data, toPeers: [peerID], with: .reliable)
                } catch { self.disconnect(reason: "Could not establish a secure connection.") }
            case .notConnected: self.disconnect(reason: "Disconnected. Connect again when you’re ready.")
            case .connecting: break
            @unknown default: self.disconnect()
            }
        }
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        DispatchQueue.main.async { [weak self] in
            guard let self, session === self.session else { return }
            self.received(data, from: peerID)
        }
    }
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) { stream.close() }
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) { progress.cancel() }
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

extension PeerLink: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID,
                    withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        DispatchQueue.main.async { [weak self] in
            guard let self, advertiser === self.advertiser, self.phase == .discovering,
                  self.selected == nil, context == Data("PalmPad-v1".utf8) else {
                invitationHandler(false, nil)
                return
            }
            self.selected = peerID
            self.peerName = peerID.displayName
            self.phase = .connecting
            self.status = "Establishing an encrypted connection…"
            self.advertiser?.stopAdvertisingPeer()
            self.beginHeartbeat()
            invitationHandler(true, self.session)
        }
    }
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        DispatchQueue.main.async { [weak self] in
            guard let self, advertiser === self.advertiser else { return }
            self.disconnect(reason: "Discovery unavailable. Allow Local Network access in System Settings, then retry.")
        }
    }
}

extension PeerLink: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        DispatchQueue.main.async { [weak self] in
            guard let self, browser === self.browser, info?["role"] == "mac", info?["version"] == "1" else { return }
            if !self.nearby.contains(peerID) { self.nearby.append(peerID) }
            self.nearby.sort { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
            if self.phase == .discovering { self.status = "Choose your Mac to connect" }
        }
    }
    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        DispatchQueue.main.async { [weak self] in
            guard let self, browser === self.browser else { return }
            self.nearby.removeAll { $0 == peerID }
        }
    }
    func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        DispatchQueue.main.async { [weak self] in
            guard let self, browser === self.browser else { return }
            self.disconnect(reason: "Allow Local Network access in Settings → Apps → PalmPad, then retry.")
        }
    }
}
