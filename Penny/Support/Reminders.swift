import Foundation
import UIKit
import UserNotifications

/// Local notifications: a daily "log today's spending" nudge and a heads-up the day
/// before each upcoming recurring bill. Everything is scheduled on device.
enum Reminders {
    static let dailyID = "penny.daily"
    static let billPrefix = "penny.bill."

    static func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        default:
            return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        }
    }

    static func isDenied() async -> Bool {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus == .denied
    }

    /// `minutes` after midnight, e.g. 20 * 60 + 30 for 8:30 PM.
    static func scheduleDaily(minutes: Int) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [dailyID])
        let content = UNMutableNotificationContent()
        content.title = "How did today go?"
        content.body = "Take ten seconds to log today’s spending in Penny."
        content.sound = .default
        var components = DateComponents()
        components.hour = minutes / 60
        components.minute = minutes % 60
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        center.add(UNNotificationRequest(identifier: dailyID, content: content, trigger: trigger))
    }

    static func cancelDaily() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [dailyID])
    }

    struct Bill {
        let id: String
        let title: String
        let amount: String
        let date: Date
    }

    /// Replaces all bill reminders with the given ones (at most 40 are kept, soonest first).
    static func scheduleBills(_ bills: [Bill], calendar: Calendar = .current, now: Date = Date()) {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { requests in
            let old = requests.map(\.identifier).filter { $0.hasPrefix(billPrefix) }
            center.removePendingNotificationRequests(withIdentifiers: old)
            for bill in bills.sorted(by: { $0.date < $1.date }).prefix(40) {
                // 9 AM the day before; skip reminders that would already be in the past.
                guard let dayBefore = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: bill.date)),
                      let fire = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: dayBefore),
                      fire > now else { continue }
                let content = UNMutableNotificationContent()
                content.title = "\(bill.title) is due tomorrow"
                content.body = "\(bill.amount) will be recorded by Penny."
                content.sound = .default
                let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
                let trigger = UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
                center.add(UNNotificationRequest(identifier: billPrefix + bill.id, content: content, trigger: trigger))
            }
        }
    }

    static func cancelBills() {
        scheduleBills([])
    }

    static func timeText(minutes: Int) -> String {
        var components = DateComponents()
        components.hour = minutes / 60
        components.minute = minutes % 60
        let date = Calendar.current.date(from: components) ?? Date()
        return date.formatted(date: .omitted, time: .shortened)
    }
}

/// Home-screen icon choices. Names must match the AppIcon-*.appiconset folders
/// listed in ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES.
struct AppIconOption: Identifiable, Hashable {
    let iconName: String?
    let label: String
    let preview: String

    var id: String { iconName ?? "default" }

    static let all: [AppIconOption] = [
        AppIconOption(iconName: nil, label: "Penny", preview: "IconPreview-Default"),
        AppIconOption(iconName: "AppIcon-Midnight", label: "Midnight", preview: "IconPreview-Midnight"),
        AppIconOption(iconName: "AppIcon-Sunrise", label: "Sunrise", preview: "IconPreview-Sunrise"),
        AppIconOption(iconName: "AppIcon-Ocean", label: "Ocean", preview: "IconPreview-Ocean"),
        AppIconOption(iconName: "AppIcon-Classic", label: "Classic", preview: "IconPreview-Classic"),
    ]

    @MainActor
    static var current: String? { UIApplication.shared.alternateIconName }

    @MainActor
    static func apply(_ option: AppIconOption, completion: @escaping (Bool) -> Void) {
        guard UIApplication.shared.supportsAlternateIcons else { return completion(false) }
        UIApplication.shared.setAlternateIconName(option.iconName) { error in
            DispatchQueue.main.async { completion(error == nil) }
        }
    }
}
