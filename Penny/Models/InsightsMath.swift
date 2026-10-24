import Foundation

/// Calculations behind the Insights screen. Pure functions so they're easy to test.
enum InsightsMath {
    struct Merchant: Identifiable, Equatable {
        let title: String
        let cents: Int
        let count: Int
        let category: LedgerCategory
        var id: String { title.lowercased() }
    }

    /// Expense descriptions ranked by total spent ("Fresh Market" ×4).
    static func topMerchants(_ entries: [LedgerEntry], limit: Int = 5) -> [Merchant] {
        struct Tally {
            var title: String
            var cents: Int
            var count: Int
            var category: LedgerCategory
        }
        var totals: [String: Tally] = [:]
        for entry in entries where entry.kind == .expense {
            let key = entry.title.trimmingCharacters(in: .whitespaces).lowercased()
            if key.isEmpty { continue }
            var tally = totals[key] ?? Tally(title: entry.title, cents: 0, count: 0, category: entry.category)
            tally.cents += entry.amountCents
            tally.count += 1
            totals[key] = tally
        }
        let merchants: [Merchant] = totals.values.map { tally in
            Merchant(title: tally.title, cents: tally.cents, count: tally.count, category: tally.category)
        }
        let ranked = merchants.sorted { lhs, rhs in
            if lhs.cents == rhs.cents { return lhs.title < rhs.title }
            return lhs.cents > rhs.cents
        }
        return Array(ranked.prefix(limit))
    }

    struct WeekdayValue: Identifiable, Equatable {
        /// 1 = Sunday … 7 = Saturday (Calendar weekday numbering).
        let weekday: Int
        let label: String
        let averageCents: Int
        var id: Int { weekday }
    }

    /// Average spending per weekday over the `days` days ending at `end` (inclusive),
    /// ordered from the calendar's first weekday.
    static func weekdayAverages(_ entries: [LedgerEntry], endingAt end: Date, days: Int = 91,
                                calendar: Calendar = .current) -> [WeekdayValue] {
        let lastDay = calendar.startOfDay(for: end)
        guard let firstDay = calendar.date(byAdding: .day, value: -(days - 1), to: lastDay),
              let after = calendar.date(byAdding: .day, value: 1, to: lastDay) else { return [] }
        var totals = Array(repeating: 0, count: 8)
        var occurrences = Array(repeating: 0, count: 8)
        var day = firstDay
        while day < after {
            occurrences[calendar.component(.weekday, from: day)] += 1
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        for entry in entries where entry.kind == .expense && entry.date >= firstDay && entry.date < after {
            totals[calendar.component(.weekday, from: entry.date)] += entry.amountCents
        }
        let symbols = calendar.shortWeekdaySymbols
        return (0..<7).map { offset in
            let weekday = (calendar.firstWeekday - 1 + offset) % 7 + 1
            let average = occurrences[weekday] == 0 ? 0 : totals[weekday] / occurrences[weekday]
            return WeekdayValue(weekday: weekday, label: symbols[weekday - 1], averageCents: average)
        }
    }

    /// Percentage change from `previous` to `current`, or nil when there's nothing to compare.
    static func change(from previous: Int, to current: Int) -> Int? {
        guard previous > 0 else { return nil }
        return Int((Double(current - previous) * 100 / Double(previous)).rounded())
    }
}
