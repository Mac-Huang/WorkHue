import SwiftUI

@main struct ConnectivityProbeApp: App {
    @StateObject private var probe = ConnectivityProbe()

    var body: some Scene {
        WindowGroup {
            Text(probe.status).font(.caption).padding()
                .task { await probe.run() }
        }
    }
}

private struct ProbeCheckpoint: Codable {
    let event: String
    let capturedAt: Date
    let snapshot: TrackingSnapshot
}

private struct ProbeReport: Codable {
    let side: String
    let cloudEnabled: Bool
    var workID: UUID?
    var studyID: UUID?
    var checkpoints: [ProbeCheckpoint] = []
    var success = false
    var error: String?
}

private enum ProbeFailure: LocalizedError {
    case invalid(String)
    var errorDescription: String? { if case let .invalid(message) = self { return message }; return nil }
}

@MainActor private final class ConnectivityProbe: ObservableObject {
    @Published var status = "Preparing actual Shared transport test"
    private let store: TimeStore
    private let directory: URL
    private let startingSnapshot: TrackingSnapshot
    private var report: ProbeReport
    private var started = false
    private var phase = 0
    private var ticks = 0
    private var settledTicks = 0

    init() {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ConnectivityProbe", isDirectory: true)
        self.directory = directory
        let trackingStore = TimeStore(repository: SnapshotRepository(fileURL: directory.appendingPathComponent("tracking.json")))
        store = trackingStore
        startingSnapshot = trackingStore.snapshot
        #if os(watchOS)
        let side = "watch"
        #else
        let side = "phone"
        #endif
        report = ProbeReport(side: side, cloudEnabled: trackingStore.cloudEnabled)
        report.checkpoints.append(ProbeCheckpoint(event: "started-empty", capturedAt: Date(), snapshot: startingSnapshot))
    }

    func run() async {
        guard !started else { return }
        started = true
        do {
            try require(!store.cloudEnabled, "Cloud must stay disabled in this probe.")
            try require(startingSnapshot.sessions.isEmpty, "The probe repository must start empty.")
            persist()
            for tick in 0..<180 {
                ticks = tick
                if tick.isMultiple(of: 4) { await store.refresh() }
                if let message = store.errorMessage { throw ProbeFailure.invalid(message) }
                #if os(watchOS)
                try await watchStep()
                #else
                try phoneStep()
                #endif
                if report.success {
                    // Keep the real transport alive briefly after success for counterpart convergence.
                    for _ in 0..<12 {
                        await store.refresh()
                        try await Task.sleep(for: .milliseconds(500))
                    }
                    checkpoint("settled-final")
                    return
                }
                try await Task.sleep(for: .milliseconds(500))
            }
            throw ProbeFailure.invalid("Timed out while waiting for the counterpart snapshot.")
        } catch {
            report.error = error.localizedDescription
            report.success = false
            status = "FAILED: \(error.localizedDescription)"
            persist()
        }
    }

    #if !os(watchOS)
    private func phoneStep() throws {
        if phase == 0, ticks >= 6 {
            guard let work = store.workloads.first(where: { $0.id == Workload.presets[0].id }) else {
                throw ProbeFailure.invalid("Work preset is missing.")
            }
            store.start(workload: work)
            guard let active = store.activeSession else { throw ProbeFailure.invalid("Phone could not start Work.") }
            try check(active, workload: Workload.presets[0], source: "iPhone", ended: false)
            report.workID = active.id
            checkpoint("phone-started-work")
            phase = 1
        } else if phase == 1, let study = store.activeSession, study.workloadID == Workload.presets[1].id {
            guard let work = store.sessions.first(where: { $0.id == report.workID }) else { throw ProbeFailure.invalid("Phone lost the Work UUID.") }
            try check(work, workload: Workload.presets[0], source: "iPhone", ended: true)
            try check(study, workload: Workload.presets[1], source: "watch", ended: false)
            report.studyID = study.id
            checkpoint("phone-received-ended-work-and-study")
            store.stop()
            try require(store.activeSession == nil, "Phone could not stop Study.")
            checkpoint("phone-stopped-study")
            phase = 2
        } else if phase == 2 {
            try validateFinal()
            settledTicks += 1
            if settledTicks >= 6 {
                report.success = true
                checkpoint("phone-converged")
                status = "PASS: Work and Study ended"
            }
        }
    }
    #endif

    #if os(watchOS)
    private func watchStep() async throws {
        if phase == 0, let work = store.activeSession, work.workloadID == Workload.presets[0].id {
            try check(work, workload: Workload.presets[0], source: "iPhone", ended: false)
            report.workID = work.id
            checkpoint("watch-received-work")
            store.stop()
            guard let ended = store.sessions.first(where: { $0.id == work.id }) else { throw ProbeFailure.invalid("Watch lost the Work UUID.") }
            try check(ended, workload: Workload.presets[0], source: "iPhone", ended: true)
            checkpoint("watch-stopped-work")
            try await Task.sleep(for: .milliseconds(300))
            guard let study = store.workloads.first(where: { $0.id == Workload.presets[1].id }) else { throw ProbeFailure.invalid("Study preset is missing.") }
            store.start(workload: study)
            guard let active = store.activeSession else { throw ProbeFailure.invalid("Watch could not start Study.") }
            try check(active, workload: Workload.presets[1], source: "watch", ended: false)
            report.studyID = active.id
            checkpoint("watch-started-study")
            phase = 1
        } else if phase == 1,
                  let study = store.sessions.first(where: { $0.id == report.studyID }), study.end != nil,
                  store.activeSession == nil {
            try validateFinal()
            report.success = true
            checkpoint("watch-received-study-stop")
            status = "PASS: Work and Study ended"
        }
    }
    #endif

    private func check(_ session: WorkSession, workload: Workload, source: String, ended: Bool) throws {
        try require(session.workloadID == workload.id, "Workload UUID differs.")
        try require(session.workloadName == workload.name, "Workload name differs.")
        try require(session.colorHex == workload.colorHex, "Workload color differs.")
        try require(session.source == source, "Session source differs.")
        try require(session.deletedAt == nil, "A recorded session was deleted.")
        try require((session.end != nil) == ended, "Session end state differs.")
        if let end = session.end { try require(end >= session.start, "An end precedes its start.") }
    }

    private func validateFinal() throws {
        try require(store.sessions.count == 2 && store.activeSession == nil, "The final snapshot must contain exactly two ended sessions.")
        guard let work = store.sessions.first(where: { $0.id == report.workID }),
              let study = store.sessions.first(where: { $0.id == report.studyID }) else {
            throw ProbeFailure.invalid("A final session UUID differs.")
        }
        try check(work, workload: Workload.presets[0], source: "iPhone", ended: true)
        try check(study, workload: Workload.presets[1], source: "watch", ended: true)
    }

    private func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        if !condition() { throw ProbeFailure.invalid(message) }
    }

    private func checkpoint(_ event: String) {
        status = event
        report.checkpoints.append(ProbeCheckpoint(event: event, capturedAt: Date(), snapshot: store.snapshot))
        persist()
    }

    private func persist() {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
            try encoder.encode(report).write(to: directory.appendingPathComponent("report.json"), options: .atomic)
        } catch { status = "Could not write probe evidence: \(error.localizedDescription)" }
    }
}
