import Foundation

@main
struct PreloadWorkloadDefinitions {
    static func main() throws {
        let expected = "/Users/xuming/Library/Developer/CoreSimulator/Devices/F0B67AC3-174C-4ED3-8F0C-B882CF29B587/data/Containers/Shared/AppGroup/E5352BE7-1262-4313-96AD-276FEFE3D65D/tracking.json"
        guard CommandLine.arguments.count == 2, CommandLine.arguments[1] == expected else {
            throw NSError(domain: "ColorFixture", code: 1, userInfo: [NSLocalizedDescriptionKey: "Use the approved disposable Watch main-app repository."])
        }
        let repository = SnapshotRepository(fileURL: URL(fileURLWithPath: expected))
        let before = try repository.load()
        let after = try repository.update { snapshot in
            let definitions = [
                Workload(id: UUID(uuidString: "00000000-0000-0000-0000-000000000100")!, name: "Black", colorHex: "000000"),
                Workload(id: UUID(uuidString: "00000000-0000-0000-0000-000000000101")!, name: "White", colorHex: "FFFFFF")
            ]
            for definition in definitions where !snapshot.workloads.contains(where: { $0.id == definition.id }) {
                snapshot.workloads.append(definition)
            }
        }
        guard before.sessions == after.sessions else {
            throw NSError(domain: "ColorFixture", code: 2, userInfo: [NSLocalizedDescriptionKey: "The fixture changed session data."])
        }
        let result: [String: Any] = ["passed": true, "sessionsUnchanged": true, "sessionCount": after.sessions.count, "workloadCount": after.workloads.count, "seededSessions": 0, "extensionOnlyState": false]
        print(String(data: try JSONSerialization.data(withJSONObject: result, options: [.sortedKeys]), encoding: .utf8)!)
    }
}
