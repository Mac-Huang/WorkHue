import AppIntents
import Foundation

struct WorkloadEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Workload"
    static var defaultQuery = WorkloadQuery()
    var id: UUID
    var name: String
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }
}

struct WorkloadQuery: EntityQuery {
    func entities(for identifiers: [UUID]) async throws -> [WorkloadEntity] {
        let snapshot = try SnapshotRepository.live.load()
        return snapshot.workloads.filter { identifiers.contains($0.id) && !$0.isArchived }.map { WorkloadEntity(id: $0.id, name: $0.name) }
    }
    func suggestedEntities() async throws -> [WorkloadEntity] {
        let snapshot = try SnapshotRepository.live.load()
        return snapshot.workloads.filter { !$0.isArchived }.map { WorkloadEntity(id: $0.id, name: $0.name) }
    }
}

struct StartWorkIntent: AppIntent {
    static var title: LocalizedStringResource = "Punch In"
    static var description = IntentDescription("Start a session with a workload color.")
    static var openAppWhenRun = false
    @Parameter(title: "Workload") var workload: WorkloadEntity
    static var parameterSummary: some ParameterSummary { Summary("Punch in for \(\.$workload)") }
    @MainActor func perform() async throws -> some IntentResult & ProvidesDialog {
        let store = TimeStore.shared
        await store.refresh()
        guard store.activeSession == nil else { return .result(dialog: "A session is already running.") }
        guard let selected = store.workloads.first(where: { $0.id == workload.id }) else { return .result(dialog: "This workload is no longer available.") }
        store.start(workload: selected, source: "Siri")
        if let error = store.errorMessage { throw IntentTrackingError.failed(error) }
        return .result(dialog: "Punched in for \(selected.name).")
    }
}

struct StopWorkIntent: AppIntent {
    static var title: LocalizedStringResource = "Punch Out"
    static var description = IntentDescription("Stop the current work session.")
    static var openAppWhenRun = false
    @MainActor func perform() async throws -> some IntentResult & ProvidesDialog {
        let store = TimeStore.shared
        await store.refresh()
        guard store.activeSession != nil else { return .result(dialog: "No session is running.") }
        store.stop()
        if let error = store.errorMessage { throw IntentTrackingError.failed(error) }
        return .result(dialog: "Punched out.")
    }
}

struct PunchinoShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: StartWorkIntent(), phrases: ["Punch in with \(.applicationName)", "Start work with \(.applicationName)"], shortTitle: "Punch In", systemImageName: "play.circle")
        AppShortcut(intent: StopWorkIntent(), phrases: ["Punch out with \(.applicationName)", "Stop work with \(.applicationName)"], shortTitle: "Punch Out", systemImageName: "stop.circle")
    }
}

private enum IntentTrackingError: LocalizedError {
    case failed(String)
    var errorDescription: String? { if case let .failed(message) = self { return message }; return nil }
}
