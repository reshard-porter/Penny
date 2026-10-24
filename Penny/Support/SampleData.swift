import Foundation
import SwiftData

/// Labeled, fictional sample data: six months of entries, a few savings goals and
/// upcoming recurring bills. Shown on request during onboarding (and in screenshot
/// mode) so the app isn't empty. Removable from the banner or Settings.
enum SampleData {
    private struct Example {
        let title: String
        let cents: Int
        let category: LedgerCategory
        let day: Int
        let hour: Int
        var note = ""
    }

    private static let examples: [Example] = [
        Example(title: "Monthly salary", cents: 420_000, category: .income, day: 1, hour: 9),
        Example(title: "Apartment rent", cents: 120_000, category: .bills, day: 2, hour: 10),
        Example(title: "Fresh Market", cents: 8_476, category: .groceries, day: 3, hour: 18),
        Example(title: "Blue Mountain Café", cents: 900, category: .dining, day: 4, hour: 8),
        Example(title: "Electricity", cents: 14_800, category: .bills, day: 5, hour: 11),
        Example(title: "Fuel stop", cents: 4_750, category: .transport, day: 6, hour: 17),
        Example(title: "Streaming plan", cents: 1_599, category: .subscriptions, day: 6, hour: 7),
        Example(title: "Weekend groceries", cents: 5_910, category: .groceries, day: 7, hour: 11),
        Example(title: "Design freelance", cents: 45_000, category: .business, day: 8, hour: 15,
                note: "Logo project for a local bakery"),
        Example(title: "Home essentials", cents: 12_400, category: .shopping, day: 9, hour: 13),
        Example(title: "Lunch with friends", cents: 2_450, category: .dining, day: 10, hour: 13),
        Example(title: "Internet", cents: 6_500, category: .bills, day: 10, hour: 9),
        Example(title: "Wellness appointment", cents: 14_900, category: .health, day: 11, hour: 16),
        Example(title: "Cinema night", cents: 2_400, category: .leisure, day: 12, hour: 20),
        Example(title: "Fresh Market", cents: 10_935, category: .groceries, day: 13, hour: 18),
        Example(title: "Ride home", cents: 1_450, category: .transport, day: 14, hour: 23),
        Example(title: "Dog food & treats", cents: 3_820, category: .pets, day: 14, hour: 12),
        Example(title: "Weekend dinner", cents: 3_290, category: .dining, day: 15, hour: 20),
        Example(title: "Bookshop", cents: 5_990, category: .education, day: 16, hour: 14),
        Example(title: "Haircut", cents: 2_500, category: .personal, day: 17, hour: 10),
        Example(title: "Fresh Market", cents: 6_440, category: .groceries, day: 17, hour: 18),
        Example(title: "Coffee & catch-up", cents: 1_850, category: .dining, day: 18, hour: 9),
        Example(title: "Train pass", cents: 1_850, category: .transport, day: 18, hour: 8),
        Example(title: "Birthday gift", cents: 4_200, category: .gifts, day: 19, hour: 15),
        Example(title: "Cashback refund", cents: 2_300, category: .refunds, day: 20, hour: 10),
        Example(title: "Fresh Market", cents: 7_120, category: .groceries, day: 21, hour: 18),
        Example(title: "Weekend getaway", cents: 18_500, category: .travel, day: 23, hour: 12),
        Example(title: "Little extras", cents: 750, category: .other, day: 24, hour: 16),
        Example(title: "Blue Mountain Café", cents: 1_100, category: .dining, day: 25, hour: 8),
        Example(title: "Dividend payout", cents: 6_400, category: .investments, day: 26, hour: 9),
    ]

    /// Spending multiplier per month back (0 = this month), so charts have shape.
    private static let monthFactors: [Double] = [1.0, 1.12, 0.94, 1.05, 0.9, 1.08]

    @MainActor
    static func insert(into context: ModelContext, now: Date = Date(), calendar: Calendar = .current) {
        insertEntries(into: context, now: now, calendar: calendar)
        insertGoals(into: context, now: now, calendar: calendar)
        insertRules(into: context, now: now, calendar: calendar)
        try? context.save()
    }

    @MainActor
    private static func insertEntries(into context: ModelContext, now: Date, calendar: Calendar) {
        for offset in 0..<monthFactors.count {
            let month = calendar.month(offset: -offset, from: now)
            let lastDay = offset == 0
                ? calendar.component(.day, from: now)
                : calendar.daysInMonth(of: month)
            for (index, example) in examples.enumerated() {
                // Skip a few entries in older months so they don't look copy-pasted.
                if offset > 0 && (index + offset) % 7 == 0 { continue }
                if offset == 0 && example.day > lastDay { continue }
                guard let date = calendar.date(byAdding: .day, value: min(example.day, lastDay) - 1, to: month),
                      let timed = calendar.date(bySettingHour: example.hour, minute: (index * 7) % 60, second: 0, of: date)
                else { continue }
                let isIncome = example.category.isIncome
                let factor = isIncome ? 1 : monthFactors[offset]
                // Small deterministic variation per entry keeps the numbers believable.
                let wiggle = isIncome || example.category == .bills ? 1 : 1 + Double((index * 13 + offset * 5) % 9 - 4) / 40
                let amount = max(100, Int((Double(example.cents) * factor * wiggle).rounded()))
                context.insert(LedgerEntry(
                    title: example.title,
                    amountCents: example.category == .bills || example.category == .subscriptions ? example.cents : amount,
                    kind: isIncome ? .income : .expense,
                    category: example.category,
                    date: timed,
                    note: example.note,
                    isSample: true))
            }
        }
    }

    @MainActor
    private static func insertGoals(into context: ModelContext, now: Date, calendar: Calendar) {
        let goals: [(String, Int, String, GoalColor, Int?, [Int])] = [
            ("Emergency fund", 500_000, "shield.lefthalf.filled", .mint, nil, [80_000, 60_000, 75_000, 50_000, 45_000]),
            ("Japan trip", 320_000, "airplane", .violet, 9, [40_000, 35_000, 30_000]),
            ("New laptop", 180_000, "laptopcomputer", .ocean, 3, [50_000, 45_000, 40_000, 9_000]),
            ("Camera lens", 65_000, "camera.fill", .sunset, nil, [30_000, 35_000]),
        ]
        for (name, target, symbol, color, monthsAhead, deposits) in goals {
            let deadline = monthsAhead.flatMap { calendar.date(byAdding: .month, value: $0, to: now) }
            let goal = SavingsGoal(name: name, targetCents: target, symbol: symbol, color: color,
                                   deadline: deadline, isSample: true)
            goal.createdAt = calendar.date(byAdding: .month, value: -deposits.count, to: now) ?? now
            context.insert(goal)
            for (index, cents) in deposits.enumerated() {
                let date = calendar.date(byAdding: .month, value: index - deposits.count + 1, to: now) ?? now
                context.insert(GoalContribution(goalID: goal.id, amountCents: cents,
                                                date: min(date, now), note: index == 0 ? "First deposit" : ""))
            }
        }
    }

    /// Recurring rules whose first occurrence is still ahead, so they show up as "upcoming"
    /// without duplicating the sample entries above.
    @MainActor
    private static func insertRules(into context: ModelContext, now: Date, calendar: Calendar) {
        let today = calendar.startOfDay(for: now)
        let nextMonth = calendar.month(offset: 1, from: now)
        func day(_ offset: Int) -> Date {
            let date = calendar.date(byAdding: .day, value: offset, to: today) ?? today
            return calendar.date(bySettingHour: 9, minute: 0, second: 0, of: date) ?? date
        }
        let firstOfNext = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: nextMonth) ?? nextMonth
        let rules: [(String, Int, EntryKind, LedgerCategory, RepeatFrequency, Date)] = [
            ("Streaming plan", 1_599, .expense, .subscriptions, .monthly, day(2)),
            ("Gym membership", 4_500, .expense, .health, .monthly, day(5)),
            ("Phone plan", 3_500, .expense, .bills, .monthly, day(9)),
            ("Apartment rent", 120_000, .expense, .bills, .monthly, firstOfNext),
            ("Monthly salary", 420_000, .income, .income, .monthly, firstOfNext),
            ("Cloud storage", 299, .expense, .subscriptions, .monthly, day(12)),
        ]
        for (title, cents, kind, category, frequency, start) in rules {
            let rule = RecurringRule(title: title, amountCents: cents, kind: kind, category: category,
                                     note: "", frequency: frequency, startDate: start)
            rule.isSample = true
            context.insert(rule)
        }
    }

    /// Removes every sample entry, goal and rule. Things the user added are kept.
    @MainActor
    static func remove(from context: ModelContext) {
        let entries = (try? context.fetch(FetchDescriptor<LedgerEntry>(predicate: #Predicate { $0.isSample }))) ?? []
        entries.forEach { context.delete($0) }
        let goals = (try? context.fetch(FetchDescriptor<SavingsGoal>(predicate: #Predicate { $0.isSample }))) ?? []
        let goalIDs = Set(goals.map(\.id))
        let contributions = (try? context.fetch(FetchDescriptor<GoalContribution>())) ?? []
        contributions.filter { goalIDs.contains($0.goalID) }.forEach { context.delete($0) }
        goals.forEach { context.delete($0) }
        let rules = (try? context.fetch(FetchDescriptor<RecurringRule>(predicate: #Predicate { $0.isSample }))) ?? []
        rules.forEach { context.delete($0) }
        try? context.save()
    }

    @MainActor
    static func hasSamples(in context: ModelContext) -> Bool {
        let count = (try? context.fetchCount(FetchDescriptor<LedgerEntry>(predicate: #Predicate { $0.isSample }))) ?? 0
        return count > 0
    }
}
