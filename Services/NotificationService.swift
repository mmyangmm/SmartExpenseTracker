import Foundation
import UserNotifications
import Combine

@MainActor
class NotificationService: ObservableObject {
    @Published var isAuthorized: Bool = false
    @Published var reminderEnabled: Bool {
        didSet {
            UserDefaults.standard.set(reminderEnabled, forKey: "reminder_enabled")
            if reminderEnabled {
                scheduleReminder()
            } else {
                cancelReminder()
            }
        }
    }
    @Published var reminderHour: Int {
        didSet {
            UserDefaults.standard.set(reminderHour, forKey: "reminder_hour")
            if reminderEnabled { scheduleReminder() }
        }
    }
    @Published var reminderMinute: Int {
        didSet {
            UserDefaults.standard.set(reminderMinute, forKey: "reminder_minute")
            if reminderEnabled { scheduleReminder() }
        }
    }

    private let reminderID = "daily_expense_reminder"

    init() {
        reminderEnabled = UserDefaults.standard.bool(forKey: "reminder_enabled")
        reminderHour    = UserDefaults.standard.object(forKey: "reminder_hour")   as? Int ?? 21
        reminderMinute  = UserDefaults.standard.object(forKey: "reminder_minute") as? Int ?? 0
    }

    // MARK: - Authorization

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            Task { @MainActor in
                self.isAuthorized = granted
                if granted && self.reminderEnabled {
                    self.scheduleReminder()
                }
            }
        }
    }

    func checkAuthStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        isAuthorized = settings.authorizationStatus == .authorized
    }

    // MARK: - Schedule

    func scheduleReminder() {
        cancelReminder()
        guard isAuthorized else { return }

        let content = UNMutableNotificationContent()
        content.title = "記帳提醒 💰"
        content.body  = "別忘了記錄今天的花費！"
        content.sound = .default
        content.badge = 1

        var components = DateComponents()
        components.hour   = reminderHour
        components.minute = reminderMinute

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: reminderID, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                print("[Notification] schedule error: \(error.localizedDescription)")
            }
        }
    }

    func cancelReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [reminderID])
    }

    var reminderTimeString: String {
        String(format: "%02d:%02d", reminderHour, reminderMinute)
    }
}
