import Foundation
import Observation
import WidgetKit

@MainActor @Observable
public final class TimeStore {
    public static let shared = TimeStore()
    public private(set) var snapshot: TrackingSnapshot
    public var errorMessage: String?
    public private(set) var syncStatus = "Saved on this device"
    public private(set) var lastSyncedAt: Date?
    public private(set) var lastRefreshDate: Date?
    public private(set) var lastRefreshSucceeded: Bool?
    public let cloudEnabled: Bool
    public private(set) var cloudAccountStatus = "Not Configured"
    public private(set) var syncErrorMessage: String?
    @ObservationIgnored private let repository: SnapshotRepository
    @ObservationIgnored private let allowsServices: Bool
    @ObservationIgnored private var refreshRequested = false
    @ObservationIgnored private var refreshWaiters: [CheckedContinuation<Void, Never>] = []
    @ObservationIgnored private var watchSync: WatchSync?
    @ObservationIgnored private var cloudSync: CloudSync?
    @ObservationIgnored private var isRefreshing = false
    @ObservationIgnored private var servicesPrepared = false
    @ObservationIgnored private var pollTask: Task<Void, Never>?
    @ObservationIgnored private var syncTask: Task<Void, Never>?

    public var sessions: [WorkSession] { snapshot.sessions.filter { $0.deletedAt == nil }.sorted { $0.start < $1.start } }
    public var workloads: [Workload] { snapshot.workloads.filter { !$0.isArchived }.sorted { $0.id.uuidString < $1.id.uuidString } }
    public var settings: TrackingSettings { snapshot.settings }
    public var activeSession: WorkSession? { snapshot.activeSession }
    public var repositoryPath: String { repository.fileURL.path }

    public init(repository: SnapshotRepository = .live, startServices: Bool = true) {
        self.repository = repository
        self.allowsServices = startServices
        let configuration = Bundle.main.object(forInfoDictionaryKey: "CloudSyncEnabled")
        self.cloudEnabled = (configuration as? Bool) == true || (configuration as? NSString)?.boolValue == true
        if cloudEnabled { cloudAccountStatus = "Not Checked" }
        do { self.snapshot = try repository.load() }
        catch {
            self.snapshot = .empty
            self.errorMessage = "Your history could not be read. The saved file remains unchanged. \(error.localizedDescription)"
        }
        guard startServices else { return }
        prepareServices()
        #if !PUNCHINO_WIDGET
        self.pollTask = Task { [weak self] in
            await self?.refresh()
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(30)) } catch { return }
                await self?.refresh()
            }
        }
        #endif
    }

    public func start(workload: Workload, source: String? = nil) {
        change { snapshot in
            guard snapshot.activeSession == nil else { return }
            try SessionValidator.validate(workload)
            let stamp = snapshot.nextModificationDate
            #if os(watchOS)
            let platformSource = "watch"
            #else
            let platformSource = "iPhone"
            #endif
            var session = WorkSession(start: Date(), workloadID: workload.id, workloadName: workload.name, colorHex: workload.colorHex, source: source ?? platformSource, modifiedAt: stamp)
            session.timerBoundaries = [TimerBoundary(id: session.id, start: session.start, timestamp: stamp)]
            snapshot.sessions.append(session)
        }
    }

    public func stop() {
        change { snapshot in
            guard let active = snapshot.activeSession,
                  let index = snapshot.sessions.firstIndex(where: { $0.id == active.id }) else { return }
            snapshot.sessions[index].timerBoundaries = active.effectiveTimerBoundaries
            snapshot.sessions[index].end = max(Date(), active.start)
            snapshot.sessions[index].automaticallyClosed = false
            snapshot.sessions[index].modifiedAt = snapshot.nextModificationDate
        }
    }

    public func saveSession(_ session: WorkSession) throws {
        let result = try repository.update { snapshot in
            try SessionValidator.validate(session, existing: snapshot.sessions)
            var saved = session
            saved.automaticallyClosed = false
            saved.modifiedAt = snapshot.nextModificationDate
            let original = snapshot.sessions.first(where: { $0.id == saved.id })
            saved.timerBoundaries = original?.effectiveTimerBoundaries ?? []
            if saved.end == nil, original == nil || original?.end != nil || original?.start != saved.start {
                saved.timerBoundaries?.append(TimerBoundary(start: saved.start, timestamp: saved.modifiedAt))
            }
            if let index = snapshot.sessions.firstIndex(where: { $0.id == saved.id }) {
                snapshot.sessions[index] = saved
            } else { snapshot.sessions.append(saved) }
        }
        didChange(result)
    }

    public func deleteSession(_ session: WorkSession) {
        change { snapshot in
            guard let index = snapshot.sessions.firstIndex(where: { $0.id == session.id }) else { return }
            let stamp = snapshot.nextModificationDate
            snapshot.sessions[index].deletedAt = stamp
            snapshot.sessions[index].modifiedAt = stamp
        }
    }

    public func deleteSessions(on day: Date) {
        change { snapshot in
            let ids = Set(TimeMath.sessions(on: day, from: snapshot.sessions).map(\.id))
            let stamp = snapshot.nextModificationDate
            for index in snapshot.sessions.indices where ids.contains(snapshot.sessions[index].id) {
                snapshot.sessions[index].deletedAt = stamp
                snapshot.sessions[index].modifiedAt = stamp
            }
        }
    }

    public func saveWorkload(_ workload: Workload) {
        change { snapshot in
            try SessionValidator.validate(workload)
            var saved = workload
            saved.name = saved.name.trimmingCharacters(in: .whitespacesAndNewlines)
            saved.colorHex = saved.colorHex.replacingOccurrences(of: "#", with: "").uppercased()
            saved.modifiedAt = snapshot.nextModificationDate
            if let index = snapshot.workloads.firstIndex(where: { $0.id == saved.id }) {
                snapshot.workloads[index] = saved
            } else { snapshot.workloads.append(saved) }
        }
    }

    public func archiveWorkload(_ workload: Workload) {
        change { snapshot in
            guard snapshot.workloads.filter({ !$0.isArchived }).count > 1 else { throw TrackingError.lastWorkload }
            guard let index = snapshot.workloads.firstIndex(where: { $0.id == workload.id }) else { return }
            snapshot.workloads[index].isArchived = true
            snapshot.workloads[index].modifiedAt = snapshot.nextModificationDate
        }
    }

    public func updateSettings(_ settings: TrackingSettings) {
        change { snapshot in
            var saved = settings
            saved.dailyLimitHours = min(TrackingSettings.dailyHoursRange.upperBound, max(TrackingSettings.dailyHoursRange.lowerBound, saved.dailyLimitHours))
            saved.weeklyGoalHours = min(TrackingSettings.weeklyHoursRange.upperBound, max(TrackingSettings.weeklyHoursRange.lowerBound, saved.weeklyGoalHours))
            saved.modifiedAt = snapshot.nextModificationDate
            snapshot.settings = saved
        }
    }

    public func refresh() async {
        lastRefreshDate = Date()
        prepareServices()
        if isRefreshing {
            refreshRequested = true
            await withCheckedContinuation { refreshWaiters.append($0) }
            return
        }
        isRefreshing = true
        repeat {
            refreshRequested = false
            await performRefresh()
        } while refreshRequested
        isRefreshing = false
        let waiters = refreshWaiters
        refreshWaiters.removeAll()
        for waiter in waiters { waiter.resume() }
    }

    @discardableResult
    public func finishPendingPairedSync(timeout: TimeInterval = 3) async -> Bool {
        prepareServices()
        guard let watchSync else { return false }
        let result = await watchSync.sendAndWaitUntilQueued(snapshot, timeout: timeout)
        switch result {
        case .queued:
            syncStatus = "Saved locally · Queued for paired device"
            return true
        case .unavailable:
            syncStatus = "Saved locally · Paired device unavailable"
        case .waitingForActivation, .timedOut, .cancelled:
            syncStatus = "Saved locally · Paired sync pending"
        case .failed(let message):
            syncStatus = "Saved locally · Paired sync pending"
            syncErrorMessage = message
        }
        return false
    }

    private func performRefresh() async {
        lastRefreshSucceeded = false
        do { snapshot = try repository.load() }
        catch {
            syncStatus = "Could not read local history"
            errorMessage = error.localizedDescription
            return
        }
        watchSync?.send(snapshot)
        if let cloudSync {
            syncStatus = "Syncing with iCloud…"
            do {
                let merged = try await cloudSync.synchronize(snapshot)
                cloudAccountStatus = await cloudSync.accountStatusDescription()
                snapshot = try repository.merge(merged)
                lastSyncedAt = Date()
                lastRefreshSucceeded = true
                syncErrorMessage = nil
                syncStatus = "Synced with iCloud"
                watchSync?.send(snapshot)
                WidgetCenter.shared.reloadAllTimelines()
            } catch {
                cloudAccountStatus = await cloudSync.accountStatusDescription()
                syncStatus = "iCloud unavailable · Saved locally"
                syncErrorMessage = error.localizedDescription
            }
        } else {
            syncStatus = watchSync?.isReachable == true ? "Connected to paired device" : "Saved on this device"
            lastRefreshSucceeded = true
        }
    }

    public func exportCSV() throws -> URL {
        try CSVExporter.write(sessions: sessions)
    }

    @discardableResult
    public func importCSV(from url: URL, replaceExisting: Bool) throws -> Int {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        let rows = try CSVImporter.parse(data: Data(contentsOf: url))
        var count = 0
        let result = try repository.update { snapshot in
            count = try CSVImporter.apply(rows, to: &snapshot, replaceExisting: replaceExisting)
        }
        didChange(result)
        return count
    }

    private func prepareServices() {
        guard allowsServices, !servicesPrepared else { return }
        servicesPrepared = true
        let sync = WatchSync { [weak self] incoming in self?.receive(incoming) }
        watchSync = sync
        sync.activate()
        if cloudEnabled {
            cloudSync = CloudSync()
            syncStatus = "Connecting to iCloud…"
        }
    }

    private func change(_ mutation: (inout TrackingSnapshot) throws -> Void) {
        do { didChange(try repository.update(mutation)) }
        catch { errorMessage = error.localizedDescription }
    }

    private func didChange(_ result: TrackingSnapshot) {
        snapshot = result
        WidgetCenter.shared.reloadAllTimelines()
        watchSync?.send(result)
        guard allowsServices else { return }
        syncTask?.cancel()
        syncTask = Task { [weak self] in
            do { try await Task.sleep(for: .milliseconds(250)) } catch { return }
            await self?.refresh()
        }
    }

    private func receive(_ incoming: TrackingSnapshot) {
        do {
            let previous = snapshot
            snapshot = try repository.merge(incoming)
            guard snapshot != previous else { return }
            WidgetCenter.shared.reloadAllTimelines()
            if cloudSync == nil { syncStatus = "Synced with paired device" }
            else { Task { await refresh() } }
        } catch { errorMessage = error.localizedDescription }
    }
}
