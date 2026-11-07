import UIKit
import CloudKit

@MainActor
final class CloudNotificationDelegate: NSObject, UIApplicationDelegate {
    private var cloudEnabled: Bool {
        guard !ProcessInfo.processInfo.arguments.contains("--ui-testing"),
              !ProcessInfo.processInfo.arguments.contains("--demo-data"),
              !ProcessInfo.processInfo.arguments.contains("--reference-empty") else { return false }
        let value = Bundle.main.object(forInfoDictionaryKey: "CloudSyncEnabled")
        return (value as? Bool) == true || (value as? NSString)?.boolValue == true
    }

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        if cloudEnabled { application.registerForRemoteNotifications() }
        return true
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        if cloudEnabled, !application.isRegisteredForRemoteNotifications { application.registerForRemoteNotifications() }
    }

    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
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
