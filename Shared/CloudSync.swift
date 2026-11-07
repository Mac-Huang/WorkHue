import Foundation
@preconcurrency import CloudKit

/// Each device owns one record. A device cannot overwrite another device's history.
actor CloudSync {
    static let subscriptionID = "punchino-private-zone-changes-v1"

    nonisolated static func isRelevantNotification(_ userInfo: [AnyHashable: Any]) -> Bool {
        guard let notification = CKNotification(fromRemoteNotificationDictionary: userInfo) as? CKRecordZoneNotification,
              notification.databaseScope == .private,
              notification.subscriptionID == subscriptionID else { return false }
        return notification.recordZoneID.map { $0.zoneName == "PunchinoSnapshots" } ?? true
    }

    private let container: CKContainer
    private let zoneID = CKRecordZone.ID(zoneName: "PunchinoSnapshots", ownerName: CKCurrentUserDefaultName)
    private let deviceID: String
    private var zoneReady = false
    private var subscriptionReady = false
    private var latestAccountStatus = "Not Checked"

    init() {
        container = CKContainer(identifier: "iCloud.com.xuming.PunchinoColor")
        let defaults = UserDefaults.standard
        if let existing = defaults.string(forKey: "PunchinoCloudDeviceID") { deviceID = existing }
        else {
            let generated = UUID().uuidString
            deviceID = generated
            defaults.set(generated, forKey: "PunchinoCloudDeviceID")
        }
    }

    func synchronize(_ local: TrackingSnapshot) async throws -> TrackingSnapshot {
        let status: CKAccountStatus
        do {
            status = try await container.accountStatus()
            latestAccountStatus = Self.description(status)
        } catch {
            latestAccountStatus = "Unavailable"
            throw error
        }
        guard status == .available else { throw CloudSyncError.noAccount }
        let database = container.privateCloudDatabase
        if !zoneReady {
            _ = try await database.save(CKRecordZone(zoneID: zoneID))
            zoneReady = true
        }
        await ensureSubscription(database: database)
        let records = try await fetchSnapshots(database: database)
        var merged = local
        for snapshot in records { merged = merged.merged(with: snapshot) }
        let recordID = CKRecord.ID(recordName: "device-\(deviceID)", zoneID: zoneID)
        let record: CKRecord
        do { record = try await database.record(for: recordID) }
        catch let error as CKError where error.code == .unknownItem { record = CKRecord(recordType: "DeviceSnapshot", recordID: recordID) }
        if let asset = record["snapshot"] as? CKAsset,
           let existingURL = asset.fileURL,
           let existingData = try? Data(contentsOf: existingURL),
           let existing = try? JSONDecoder().decode(TrackingSnapshot.self, from: existingData),
           existing == merged { return merged }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("cloud-\(UUID().uuidString).json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        try encoder.encode(merged).write(to: url, options: .atomic)
        defer { try? FileManager.default.removeItem(at: url) }
        record["snapshot"] = CKAsset(fileURL: url)
        record["updatedAt"] = Date() as CKRecordValue
        _ = try await database.save(record)
        return merged
    }

    private func ensureSubscription(database: CKDatabase) async {
        guard !subscriptionReady else { return }
        let subscription = CKRecordZoneSubscription(zoneID: zoneID, subscriptionID: Self.subscriptionID)
        let info = CKSubscription.NotificationInfo()
        info.shouldSendContentAvailable = true
        subscription.notificationInfo = info
        do {
            _ = try await database.save(subscription)
            subscriptionReady = true
        } catch {
            // The next refresh retries setup. Local history and normal sync remain available.
        }
    }

    func accountStatusDescription() -> String { latestAccountStatus }

    private static func description(_ status: CKAccountStatus) -> String {
        switch status {
        case .available: return "Available"
        case .couldNotDetermine: return "Could Not Determine"
        case .restricted: return "Restricted"
        case .noAccount: return "No Account"
        case .temporarilyUnavailable: return "Temporarily Unavailable"
        @unknown default: return "Unknown"
        }
    }

    private func fetchSnapshots(database: CKDatabase) async throws -> [TrackingSnapshot] {
        let zoneID = self.zoneID
        return try await withCheckedThrowingContinuation { continuation in
            let collector = SnapshotCollector()
            let configuration = CKFetchRecordZoneChangesOperation.ZoneConfiguration()
            configuration.previousServerChangeToken = nil
            let operation = CKFetchRecordZoneChangesOperation(recordZoneIDs: [zoneID], configurationsByRecordZoneID: [zoneID: configuration])
            // CloudKit follows all pages before it invokes the final result block.
            operation.fetchAllChanges = true
            operation.recordWasChangedBlock = { _, result in
                switch result {
                case .success(let record):
                    guard record.recordType == "DeviceSnapshot",
                          let asset = record["snapshot"] as? CKAsset,
                          let url = asset.fileURL else { return }
                    do {
                        let snapshot = try JSONDecoder().decode(TrackingSnapshot.self, from: Data(contentsOf: url))
                        guard snapshot.schemaVersion <= 1 else { throw TrackingError.unsupportedSchema }
                        collector.append(snapshot)
                    } catch { collector.setError(error) }
                case .failure(let error): collector.setError(error)
                }
            }
            operation.recordZoneFetchResultBlock = { _, result in
                if case .failure(let error) = result { collector.setError(error) }
            }
            operation.fetchRecordZoneChangesResultBlock = { result in
                switch result {
                case .failure(let error): continuation.resume(throwing: error)
                case .success:
                    let collected = collector.result()
                    continuation.resume(with: collected)
                }
            }
            database.add(operation)
        }
    }
}

private final class SnapshotCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var snapshots: [TrackingSnapshot] = []
    private var error: Error?
    func append(_ snapshot: TrackingSnapshot) {
        lock.lock()
        defer { lock.unlock() }
        snapshots.append(snapshot)
    }
    func setError(_ error: Error) {
        lock.lock()
        defer { lock.unlock() }
        self.error = error
    }
    func result() -> Result<[TrackingSnapshot], Error> {
        lock.lock()
        defer { lock.unlock() }
        if let error { return .failure(error) }
        return .success(snapshots)
    }
}

private enum CloudSyncError: LocalizedError {
    case noAccount
    var errorDescription: String? { "Sign in to iCloud to sync your history. Your sessions remain saved on this device." }
}
