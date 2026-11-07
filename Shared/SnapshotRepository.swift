import Foundation

public struct SnapshotRepository: Sendable {
    public static let appGroup = "group.com.xuming.PunchinoColor"
    public let fileURL: URL

    public init(fileURL: URL) { self.fileURL = fileURL }

    public static var live: SnapshotRepository {
        let manager = FileManager.default
        let directory: URL
        if let override = ProcessInfo.processInfo.environment["PUNCHINO_DATA_DIRECTORY"] {
            directory = URL(fileURLWithPath: override, isDirectory: true)
        } else {
            #if os(iOS) || os(watchOS)
            directory = manager.containerURL(forSecurityApplicationGroupIdentifier: appGroup)
                ?? manager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("PunchinoColor", isDirectory: true)
            #else
            directory = manager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("PunchinoColor", isDirectory: true)
            #endif
        }
        return SnapshotRepository(fileURL: directory.appendingPathComponent("tracking.json"))
    }

    public func load() throws -> TrackingSnapshot {
        if !FileManager.default.fileExists(atPath: fileURL.path) { return .empty }
        var result: Result<TrackingSnapshot, Error>!
        var coordinationError: NSError?
        NSFileCoordinator().coordinate(readingItemAt: fileURL, options: [], error: &coordinationError) { url in
            result = Result { try read(url) }
        }
        if let coordinationError { throw coordinationError }
        return try result.get()
    }

    @discardableResult
    public func update(_ mutation: (inout TrackingSnapshot) throws -> Void) throws -> TrackingSnapshot {
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        var result: Result<TrackingSnapshot, Error>!
        var coordinationError: NSError?
        NSFileCoordinator().coordinate(writingItemAt: fileURL, options: .forMerging, error: &coordinationError) { url in
            result = Result {
                var snapshot = FileManager.default.fileExists(atPath: url.path) ? try read(url) : .empty
                try mutation(&snapshot)
                snapshot.reconcileActiveSessions()
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.sortedKeys]
                try encoder.encode(snapshot).write(to: url, options: [.atomic])
                return snapshot
            }
        }
        if let coordinationError { throw coordinationError }
        return try result.get()
    }

    @discardableResult
    public func merge(_ snapshot: TrackingSnapshot) throws -> TrackingSnapshot {
        try update { $0 = $0.merged(with: snapshot) }
    }

    private func read(_ url: URL) throws -> TrackingSnapshot {
        let snapshot = try JSONDecoder().decode(TrackingSnapshot.self, from: Data(contentsOf: url))
        guard snapshot.schemaVersion <= 1 else { throw TrackingError.unsupportedSchema }
        return snapshot
    }
}
