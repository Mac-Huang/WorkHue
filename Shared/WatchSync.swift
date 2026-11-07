import Foundation
import CryptoKit
@preconcurrency import WatchConnectivity

@MainActor
final class WatchSync: NSObject, WCSessionDelegate {
    enum QueueResult {
        case queued
        case waitingForActivation
        case unavailable
        case timedOut
        case cancelled
        case failed(String)
    }

    private let onReceive: @MainActor (TrackingSnapshot) -> Void
    private var session: WCSession?
    private var pendingSnapshot: TrackingSnapshot?
    private var lastQueuedFullDigest: String?
    var isReachable: Bool { session?.isReachable == true }

    init(onReceive: @escaping @MainActor (TrackingSnapshot) -> Void) { self.onReceive = onReceive }

    func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        self.session = session
        session.delegate = self
        session.activate()
    }

    @discardableResult
    func send(_ snapshot: TrackingSnapshot) -> QueueResult {
        pendingSnapshot = snapshot
        guard let session else { return .unavailable }
        guard session.activationState == .activated else { return .waitingForActivation }
        #if os(iOS)
        guard session.isPaired, session.isWatchAppInstalled else { return .unavailable }
        #endif
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data: Data
        do { data = try encoder.encode(snapshot) }
        catch { return .failed(error.localizedDescription) }
        if data.count < 50_000 {
            return sendImmediate(data, through: session)
        } else {
            var immediateResult: QueueResult?
            if let patch = snapshot.immediatePatch(), let patchData = try? encoder.encode(patch) {
                immediateResult = sendImmediate(patchData, through: session)
            }
            let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
            guard lastQueuedFullDigest != digest else { return immediateResult ?? .queued }
            if session.outstandingFileTransfers.contains(where: { $0.file.metadata?["digest"] as? String == digest }) {
                lastQueuedFullDigest = digest
                return immediateResult ?? .queued
            }
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("watch-\(UUID().uuidString).json")
            do {
                try data.write(to: url, options: .atomic)
                session.transferFile(url, metadata: ["type": "snapshot", "digest": digest])
                lastQueuedFullDigest = digest
                return .queued
            } catch { return immediateResult ?? .failed(error.localizedDescription) }
        }
    }

    func sendAndWaitUntilQueued(_ snapshot: TrackingSnapshot, timeout: TimeInterval) async -> QueueResult {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .seconds(max(0, timeout)))
        while true {
            if Task.isCancelled { return .cancelled }
            let result = send(snapshot)
            guard case .waitingForActivation = result else { return result }
            guard clock.now < deadline else { return .timedOut }
            do { try await Task.sleep(for: min(.milliseconds(50), clock.now.duration(to: deadline))) }
            catch { return .cancelled }
        }
    }

    private func sendImmediate(_ data: Data, through session: WCSession) -> QueueResult {
        let result: QueueResult
        do {
            try session.updateApplicationContext(["snapshot": data])
            result = .queued
        } catch { result = .failed(error.localizedDescription) }
        if session.isReachable { session.sendMessageData(data, replyHandler: nil, errorHandler: nil) }
        return result
    }

    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            if let data = session.receivedApplicationContext["snapshot"] as? Data { self.decode(data) }
            if let pendingSnapshot { send(pendingSnapshot) }
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor [weak self] in
            guard let self, let snapshot = self.pendingSnapshot else { return }
            self.send(snapshot)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        guard let data = applicationContext["snapshot"] as? Data else { return }
        Task { @MainActor [weak self] in self?.decode(data) }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessageData messageData: Data) {
        Task { @MainActor [weak self] in self?.decode(messageData) }
    }

    nonisolated func session(_ session: WCSession, didReceive file: WCSessionFile) {
        guard file.metadata?["type"] as? String == "snapshot", let data = try? Data(contentsOf: file.fileURL) else { return }
        Task { @MainActor [weak self] in self?.decode(data) }
    }

    nonisolated func session(_ session: WCSession, didFinish fileTransfer: WCSessionFileTransfer, error: Error?) {
        let digest = fileTransfer.file.metadata?["digest"] as? String
        try? FileManager.default.removeItem(at: fileTransfer.file.fileURL)
        if error != nil {
            Task { @MainActor [weak self] in
                if self?.lastQueuedFullDigest == digest { self?.lastQueuedFullDigest = nil }
            }
        }
    }

    #if os(iOS)
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        Task { @MainActor [weak self] in
            self?.lastQueuedFullDigest = nil
            session.activate()
        }
    }
    #endif

    private func decode(_ data: Data) {
        guard let incoming = try? JSONDecoder().decode(TrackingSnapshot.self, from: data), incoming.schemaVersion <= 1 else { return }
        onReceive(incoming)
    }
}
