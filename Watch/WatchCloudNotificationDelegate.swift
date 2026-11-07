import WatchKit
import CloudKit

@MainActor
final class WatchCloudNotificationDelegate: NSObject, WKApplicationDelegate {
    private var cloudEnabled: Bool {
        guard !ProcessInfo.processInfo.arguments.contains("--ui-testing") else { return false }
        let value = Bundle.main.object(forInfoDictionaryKey: "CloudSyncEnabled")
        return (value as? Bool) == true || (value as? NSString)?.boolValue == true
    }

    func applicationDidFinishLaunching() {
        if cloudEnabled { WKApplication.shared().registerForRemoteNotifications() }
    }

    func applicationDidBecomeActive() {
        let application = WKApplication.shared()
        if cloudEnabled, !application.isRegisteredForRemoteNotifications { application.registerForRemoteNotifications() }
    }

    func didReceiveRemoteNotification(_ userInfo: [AnyHashable: Any], fetchCompletionHandler completionHandler: @escaping (WKBackgroundFetchResult) -> Void) {
        guard cloudEnabled, CloudSync.isRelevantNotification(userInfo) else {
            completionHandler(.noData)
            return
        }
        Task { @MainActor in
            let store = TimeStore.shared
            let before = store.snapshot
            await store.refresh()
            guard store.lastRefreshSucceeded == true else { completionHandler(.failed); return }
            completionHandler(store.snapshot == before ? .noData : .newData)
        }
    }
}
