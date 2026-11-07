import SwiftUI

@main
struct PunchinoApp: App {
    @UIApplicationDelegateAdaptor(CloudNotificationDelegate.self) private var cloudDelegate
    @State private var store: TimeStore
    @State private var showPunchIn = false
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let testing = ProcessInfo.processInfo.arguments.contains("--ui-testing")
        let demo = ProcessInfo.processInfo.arguments.contains("--demo-data")
        let reference = ProcessInfo.processInfo.arguments.contains("--reference-empty")
        if testing || demo || reference {
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(reference ? "punchino-reference.json" : (demo ? "punchino-demo.json" : "punchino-ui-tests.json"))
            if !ProcessInfo.processInfo.arguments.contains("--preserve-data") { try? FileManager.default.removeItem(at: url) }
            let repository = SnapshotRepository(fileURL: url)
            if demo { _ = try? repository.update { $0 = DemoData.snapshot() } }
            if reference { _ = try? repository.update { $0 = TrackingSnapshot(settings: TrackingSettings(weeklyGoalHours: 21, dailyLimitHours: 3, themeHex: "0099FF", focus: .momentum)) } }
            _store = State(initialValue: TimeStore(repository: repository, startServices: false))
        } else {
            _store = State(initialValue: TimeStore.shared)
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .modifier(ReferenceDisplaySettings(enabled: ProcessInfo.processInfo.arguments.contains("--reference-empty")))
                .environment(store)
                .tint(store.settings.tint)
                .preferredColorScheme((ProcessInfo.processInfo.arguments.contains("--demo-dark") || ProcessInfo.processInfo.arguments.contains("--reference-empty")) ? .dark : nil)
                .onOpenURL { url in
                    if url.host == "punch-in" { showPunchIn = store.activeSession == nil }
                    if url.host == "punch-out" { store.stop() }
                }
                .sheet(isPresented: $showPunchIn) {
                    WorkloadPickerView { workload in
                        store.start(workload: workload)
                        showPunchIn = false
                    }
                    .environment(store)
                }
                .task { await store.refresh() }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { Task { await store.refresh() } }
                }
        }
    }
}

// Match the original phone's observed accessibility settings only in the isolated reference fixture.
private struct ReferenceDisplaySettings: ViewModifier {
    let enabled: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if enabled {
            content.dynamicTypeSize(.medium).environment(\.legibilityWeight, .bold)
        } else {
            content
        }
    }
}
import Foundation

// This fixture requires the explicit --demo-data launch argument.
enum DemoData {
    static func snapshot(now: Date = Date()) -> TrackingSnapshot {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        var sessions: [WorkSession] = []
        for offset in 1...95 {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
            let weekday = calendar.component(.weekday, from: day)
            if weekday == 1 || weekday == 7 { continue }
            let workload = Workload.presets[offset % 3]
            let hours = [4.2, 6.2, 6.8, 8.0, 7.5, 9.0, 3.8][offset % 7]
            let start = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: day)!
            sessions.append(WorkSession(start: start, end: start.addingTimeInterval(hours * 3600), workloadID: workload.id, workloadName: workload.name, colorHex: workload.colorHex, source: offset % 4 == 0 ? "Siri" : "iPhone"))
        }
        return TrackingSnapshot(sessions: sessions, settings: TrackingSettings(weeklyGoalHours: 41, dailyLimitHours: 9))
    }
}
