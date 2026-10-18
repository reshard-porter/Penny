import Foundation
import SwiftData

/// Creates entries for recurring rules that have come due. Runs at launch and
/// whenever Penny returns to the foreground, so nothing is missed while closed.
enum RecurringEngine {
    /// Safety cap so a very old start date can never create an unbounded backlog in one pass.
    static let maxPerRule = 400

    @MainActor
    @discardableResult
    static func run(context: ModelContext, now: Date = Date(), calendar: Calendar = .current) -> Int {
        let rules = (try? context.fetch(FetchDescriptor<RecurringRule>())) ?? []
        let startOfToday = calendar.startOfDay(for: now)
        let endOfToday = calendar.date(byAdding: .day, value: 1, to: startOfToday) ?? now
        var created = 0

        for rule in rules where rule.isActive {
            var count = 0
            while rule.nextDate < endOfToday && count < maxPerRule {
                context.insert(LedgerEntry(
                    title: rule.title,
                    amountCents: rule.amountCents,
                    kind: rule.kind,
                    category: rule.category,
                    date: rule.nextDate,
                    note: rule.note,
                    ruleID: rule.id))
                rule.generatedCount += 1
                count += 1
            }
            created += count
        }

        if created > 0 { try? context.save() }
        return created
    }
}
