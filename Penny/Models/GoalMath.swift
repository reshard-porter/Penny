import Foundation

/// Calculations for savings goals. Saved amounts are derived from contributions.
enum GoalMath {
    /// Total saved per goal ID.
    static func saved(_ contributions: [GoalContribution]) -> [UUID: Int] {
        contributions.reduce(into: [:]) { totals, item in totals[item.goalID, default: 0] += item.amountCents }
    }

    /// 0…1+ (can exceed 1 when a goal is over-funded).
    static func progress(saved: Int, target: Int) -> Double {
        guard target > 0 else { return 0 }
        return max(0, Double(saved) / Double(target))
    }

    /// What to set aside each month to reach the target by the deadline (nil without a deadline
    /// or once the goal is reached). The current month counts, so a deadline this month needs it all now.
    static func monthlyNeeded(saved: Int, target: Int, deadline: Date?, now: Date = Date(),
                              calendar: Calendar = .current) -> Int? {
        guard let deadline, saved < target else { return nil }
        let months = calendar.dateComponents([.month], from: calendar.startOfMonth(for: now),
                                             to: calendar.startOfMonth(for: deadline)).month ?? 0
        let remaining = target - saved
        return Int((Double(remaining) / Double(max(months, 0) + 1)).rounded(.up))
    }

    /// Average monthly saving over the goal's lifetime, used to estimate a finish date.
    static func projectedFinish(saved: Int, target: Int, createdAt: Date, now: Date = Date(),
                                calendar: Calendar = .current) -> Date? {
        guard saved > 0, saved < target else { return nil }
        let days = max(1, calendar.dateComponents([.day], from: createdAt, to: now).day ?? 1)
        let perDay = Double(saved) / Double(days)
        guard perDay > 0 else { return nil }
        let daysLeft = Double(target - saved) / perDay
        guard daysLeft < 365 * 30 else { return nil }
        return calendar.date(byAdding: .day, value: Int(daysLeft.rounded(.up)), to: now)
    }
}
