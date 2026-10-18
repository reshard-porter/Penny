import Foundation
import SwiftData

/// Labeled, fictional sample entries for this month and last month, shown on
/// first launch so the app isn't empty. Removable from the banner or Settings.
enum SampleData {
    private static let examples: [(String, Int, LedgerCategory, Int)] = [
        ("Monthly salary", 420_000, .income, 1),
        ("Apartment rent", 120_000, .bills, 2),
        ("Fresh Market", 8_476, .groceries, 3),
        ("Morning coffee", 900, .dining, 4),
        ("Electricity", 14_800, .bills, 5),
        ("Fuel stop", 4_750, .transport, 6),
        ("Weekend groceries", 5_910, .groceries, 7),
        ("Design freelance", 45_000, .income, 8),
        ("Home essentials", 12_400, .shopping, 9),
        ("Lunch with friends", 2_450, .dining, 10),
        ("Internet", 6_500, .bills, 10),
        ("Wellness appointment", 14_900, .health, 11),
        ("Cinema night", 2_400, .leisure, 12),
        ("Fresh Market", 10_935, .groceries, 13),
        ("Ride home", 1_450, .transport, 14),
        ("Weekend dinner", 3_290, .dining, 15),
        ("Bookshop", 5_990, .shopping, 16),
        ("Fresh Market", 6_440, .groceries, 17),
        ("Coffee & catch-up", 1_850, .dining, 18),
        ("Train pass", 1_850, .transport, 18),
        ("Little extras", 750, .other, 18),
    ]

    @MainActor
    static func insert(into context: ModelContext, now: Date = Date(), calendar: Calendar = .current) {
        for offset in 0..<2 {
            let month = calendar.month(offset: -offset, from: now)
            let lastDay = offset == 0
                ? calendar.component(.day, from: now)
                : calendar.daysInMonth(of: month)
            for (title, cents, category, day) in examples {
                guard let date = calendar.date(byAdding: .day, value: min(day, lastDay) - 1, to: month) else { continue }
                let isIncome = category == .income
                // Last month runs ~14% higher so Insights has a comparison to show.
                let amount = offset == 1 && !isIncome ? Int((Double(cents) * 1.14).rounded()) : cents
                context.insert(LedgerEntry(
                    title: title,
                    amountCents: amount,
                    kind: isIncome ? .income : .expense,
                    category: category,
                    date: calendar.date(bySettingHour: 12, minute: 0, second: 0, of: date) ?? date,
                    isSample: true))
            }
        }
        try? context.save()
    }
}
