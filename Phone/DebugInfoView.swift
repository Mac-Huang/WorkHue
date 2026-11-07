import SwiftUI

struct DebugInfoView: View {
    @Environment(TimeStore.self) private var store
    @State private var liveMonitoring = false
    private var mostRecent: WorkSession? { store.sessions.max { $0.start < $1.start } }

    var body: some View {
        Form {
            Section("Status") {
                LabeledContent("Last Refresh", value: dateString(store.lastRefreshDate))
            }
            Section("CloudKit") {
                LabeledContent("Account Status", value: store.cloudAccountStatus)
                LabeledContent("Last Check", value: dateString(store.lastRefreshDate))
                HStack { Text("Sync Time"); Spacer(); if let date = store.lastSyncedAt { Text(date, style: .relative).foregroundStyle(.secondary) } else { Text("Never").foregroundStyle(.secondary) } }
            }
            Section("Monitoring") {
                Toggle("Live Sync Monitoring", isOn: $liveMonitoring)
            }
            Section("Sessions") { LabeledContent("Local Count", value: String(store.sessions.count)) }
            if let session = mostRecent {
                Section("Most Recent Session") {
                    LabeledContent("Start", value: dateString(session.start))
                    LabeledContent("End", value: session.end.map { dateString($0) } ?? "In progress")
                    LabeledContent("Source", value: session.source)
                }
            }
            Section("App Group") {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Store Path")
                    Text(store.repositoryPath)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.trailing)
                        .lineLimit(2)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
            if let message = store.syncErrorMessage {
                Section("Sync Status") { Text(message).foregroundStyle(.secondary) }
            }
        }
        .textCase(nil)
        .navigationTitle("Debug")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { Task { await store.refresh() } } label: { Image(systemName: "arrow.clockwise") }
                    .accessibilityLabel("Refresh")
            }
        }
        .task { await store.refresh() }
        .task(id: liveMonitoring) {
            guard liveMonitoring else { return }
            while !Task.isCancelled {
                await store.refresh()
                do { try await Task.sleep(for: .seconds(2)) } catch { return }
            }
        }
    }
    private func dateString(_ date: Date?) -> String {
        guard let date else { return "Never" }
        return date.formatted(date: .abbreviated, time: .standard)
    }
}
