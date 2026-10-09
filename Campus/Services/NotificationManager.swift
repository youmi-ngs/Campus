import Foundation
import SwiftData
import UserNotifications

/// 通知1件分の内容。SwiftData のモデルを跨いで持ち回さないよう値型にしておく。
struct ReminderPlan: Sendable {
    var id: String
    var title: String
    var body: String
    var subtitle: String
    var fireDate: DateComponents
}

/// 通知の許可・登録・貼り替えをまとめて扱う。
@MainActor
@Observable
final class NotificationManager {
    static let shared = NotificationManager()

    // デリゲート（メインアクター外）からも参照するため nonisolated にしておく。
    nonisolated static let categoryIdentifier = "TASK_REMINDER"
    nonisolated static let completeActionIdentifier = "TASK_COMPLETE"
    /// iOS が1アプリに許す未配信の通知は64件まで。余裕を持たせて60件で打ち止めにする。
    nonisolated static let scheduleLimit = 60

    private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined

    private let center = UNUserNotificationCenter.current()
    private let delegate = NotificationDelegate()

    private init() {}

    /// 起動時に一度呼ぶ。通知からの「完了にする」を受け取れるようにする。
    func bootstrap() {
        center.delegate = delegate

        // 先送りは用意しない。出席は数分、FS は当日しか手を動かせないため。
        let complete = UNNotificationAction(
            identifier: Self.completeActionIdentifier,
            title: "Mark as Done",
            options: [.authenticationRequired]
        )
        let category = UNNotificationCategory(
            identifier: Self.categoryIdentifier,
            actions: [complete],
            intentIdentifiers: [],
            options: []
        )
        center.setNotificationCategories([category])
    }

    func refreshAuthorizationStatus() async {
        let settings = await center.notificationSettings()
        authorizationStatus = settings.authorizationStatus
    }

    /// まだ聞いていなければ許可を求める。すでに拒否されている場合は何もしない。
    @discardableResult
    func requestAuthorizationIfNeeded() async -> Bool {
        await refreshAuthorizationStatus()
        switch authorizationStatus {
        case .notDetermined:
            let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
            await refreshAuthorizationStatus()
            return granted
        case .authorized, .provisional, .ephemeral:
            return true
        default:
            return false
        }
    }

    /// 未完了のやることを元に、保留中の通知を作り直す。
    func reschedule(with plans: [ReminderPlan], badgeCount: Int) async {
        center.removeAllPendingNotificationRequests()

        guard authorizationStatus == .authorized
            || authorizationStatus == .provisional
            || authorizationStatus == .ephemeral
        else {
            return
        }

        for plan in plans.prefix(Self.scheduleLimit) {
            let content = UNMutableNotificationContent()
            content.title = plan.title
            content.subtitle = plan.subtitle
            content.body = plan.body
            content.sound = .default
            content.categoryIdentifier = Self.categoryIdentifier
            content.userInfo = ["taskUID": plan.id]
            content.interruptionLevel = .active

            let trigger = UNCalendarNotificationTrigger(dateMatching: plan.fireDate, repeats: false)
            let request = UNNotificationRequest(identifier: plan.id, content: content, trigger: trigger)
            try? await center.add(request)
        }

        try? await center.setBadgeCount(max(0, badgeCount))
    }
}

/// 通知のタップや「完了にする」を受けてデータを更新する。
private final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        guard
            let raw = response.notification.request.content.userInfo["taskUID"] as? String,
            let uid = UUID(uuidString: raw)
        else { return }

        guard response.actionIdentifier == NotificationManager.completeActionIdentifier else { return }
        await MainActor.run { Self.update(uid: uid) { $0.markDone(true) } }

        await TaskSyncCoordinator.shared.refreshNotifications()
    }

    @MainActor
    private static func update(uid: UUID, _ change: (TaskItem) -> Void) {
        let context = ModelContext(AppContainer.shared)
        let descriptor = FetchDescriptor<TaskItem>(predicate: #Predicate { $0.uid == uid })
        guard let task = try? context.fetch(descriptor).first else { return }
        change(task)
        try? context.save()
    }
}
