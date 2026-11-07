import SwiftUI
import WatchConnectivity

@main struct LifetimeProbeApp: App {
    @StateObject private var probe = LifetimeProbe()
    var body: some Scene {
        WindowGroup { Text(probe.status).font(.caption).padding().task { await probe.run() } }
    }
}

private struct Report: Codable {
    let side: String
    let mode: String
    let processID: Int32
    var finished = false
    var error: String?
    var sessionID: UUID?
    var initialSnapshot: TrackingSnapshot?
    var stoppedSnapshot: TrackingSnapshot?
    var finalSnapshot: TrackingSnapshot?
    var converged = false
    var storeReleased: Bool?
    var queueAccepted: Bool?
    var syncStatus: String?
    var barrierElapsedSeconds: Double?
    var activationAtReturn: Int?
    var delegateAtReturn: Bool?
    var activationAfterWait: Int?
    var delegateAfterWait: Bool?
}

@MainActor private final class LifetimeProbe: ObservableObject {
    @Published var status = "Preparing lifetime probe"
    private let directory: URL
    private let repository: SnapshotRepository
    private var retainedStore: TimeStore?
    private weak var temporaryStore: TimeStore?
    private var report: Report
    private var started = false

    init() {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("WidgetLifetimeProbe", isDirectory: true)
        self.directory = directory
        repository = SnapshotRepository(fileURL: directory.appendingPathComponent("tracking.json"))
        #if os(watchOS)
        let side = "watch"
        let arguments = ProcessInfo.processInfo.arguments
        let mode = arguments.contains("--receive") ? "receive" : arguments.contains("--retained") ? "retained" : arguments.contains("--baseline") ? "baseline" : arguments.contains("--zero-timeout") ? "zero-timeout" : "short-lived"
        #else
        let side = "phone"
        let mode = "observe"
        #endif
        report = Report(side: side, mode: mode, processID: ProcessInfo.processInfo.processIdentifier)
    }

    func run() async {
        guard !started else { return }
        started = true
        do {
            #if os(watchOS)
            if report.mode == "receive" { try await receive() }
            else { try await stopInFreshProcess(retain: report.mode == "retained") }
            #else
            try await phone()
            #endif
        } catch { report.error = error.localizedDescription; persist() }
    }

    #if !os(watchOS)
    private func phone() async throws {
        let store = TimeStore(repository: repository)
        retainedStore = store
        guard !store.cloudEnabled, store.sessions.isEmpty else { throw CocoaError(.validationMissingMandatoryProperty) }
        try await Task.sleep(for: .seconds(3))
        store.start(workload: Workload.presets[0])
        report.sessionID = store.activeSession?.id
        report.initialSnapshot = store.snapshot
        persist()
        for tick in 0..<160 {
            if tick.isMultiple(of: 4) { await store.refresh() }
            if let session = store.sessions.first(where: { $0.id == report.sessionID }), session.end != nil {
                report.converged = true
            }
            report.finalSnapshot = store.snapshot
            persist()
            try await Task.sleep(for: .milliseconds(500))
        }
        report.finished = true
        persist()
    }
    #else
    private func receive() async throws {
        let store = TimeStore(repository: repository)
        retainedStore = store
        guard !store.cloudEnabled else { throw CocoaError(.validationMissingMandatoryProperty) }
        for tick in 0..<80 {
            if tick.isMultiple(of: 4) { await store.refresh() }
            if let active = store.activeSession {
                report.sessionID = active.id
                report.initialSnapshot = store.snapshot
                report.finalSnapshot = store.snapshot
                report.finished = true
                persist()
                return
            }
            try await Task.sleep(for: .milliseconds(500))
        }
        throw CocoaError(.coderReadCorrupt)
    }

    private func stopInFreshProcess(retain: Bool) async throws {
        report.initialSnapshot = try repository.load()
        report.sessionID = report.initialSnapshot?.activeSession?.id
        guard report.sessionID != nil else { throw CocoaError(.validationMissingMandatoryProperty) }
        try await stopUsingLocalStore(retain: retain)
        report.storeReleased = temporaryStore == nil
        report.activationAtReturn = WCSession.default.activationState.rawValue
        report.delegateAtReturn = WCSession.default.delegate != nil
        persist()
        // This process remains alive, but it creates no further store and sends no transport calls.
        try await Task.sleep(for: .seconds(15))
        report.finalSnapshot = try repository.load()
        report.activationAfterWait = WCSession.default.activationState.rawValue
        report.delegateAfterWait = WCSession.default.delegate != nil
        report.finished = true
        persist()
    }

    private func stopUsingLocalStore(retain: Bool) async throws {
        let store = TimeStore(repository: repository, startServices: true)
        temporaryStore = store
        if retain { retainedStore = store }
        guard !store.cloudEnabled else { throw CocoaError(.validationMissingMandatoryProperty) }
        store.stop()
        await store.refresh()
        if report.mode != "baseline" {
            let began = ContinuousClock.now
            report.queueAccepted = await store.finishPendingPairedSync(timeout: report.mode == "zero-timeout" ? 0 : 3)
            let elapsed = began.duration(to: .now).components
            report.barrierElapsedSeconds = Double(elapsed.seconds) + Double(elapsed.attoseconds) / 1e18
        }
        report.syncStatus = store.syncStatus
        report.stoppedSnapshot = store.snapshot
        if let error = store.errorMessage { throw NSError(domain: "LifetimeProbe", code: 1, userInfo: [NSLocalizedDescriptionKey: error]) }
    }
    #endif

    private func persist() {
        status = report.mode + (report.finished ? " finished" : " running")
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
            try encoder.encode(report).write(to: directory.appendingPathComponent(report.mode + "-report.json"), options: .atomic)
        } catch { status = error.localizedDescription }
    }
}
