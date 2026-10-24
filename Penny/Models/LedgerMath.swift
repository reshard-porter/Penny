import Foundation

extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        self.date(from: dateComponents([.year, .month], from: date)) ?? startOfDay(for: date)
    }

    func month(offset: Int, from date: Date) -> Date {
        self.date(byAdding: .month, value: offset, to: startOfMonth(for: date)) ?? date
    }

    func daysInMonth(of date: Date) -> Int {
        range(of: .day, in: .month, for: date)?.count ?? 30
    }

    func endOfMonth(for date: Date) -> Date {
        let next = month(offset: 1, from: date)
        return self.date(byAdding: .second, value: -1, to: next) ?? date
    }

    func endOfDay(for date: Date) -> Date {
        let start = startOfDay(for: date)
        return self.date(byAdding: .second, value: 86_399, to: start) ?? date
    }

    /// Whole days from today to `date` (0 = today, 1 = tomorrow).
    func daysFromToday(to date: Date, now: Date = Date()) -> Int {
        dateComponents([.day], from: startOfDay(for: now), to: startOfDay(for: date)).day ?? 0
    }
}

enum DateText {
    static func monthKey(_ date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month], from: date)
        let year = parts.year ?? 2000
        let month = parts.month ?? 1
        return "\(year)-\(month < 10 ? "0" : "")\(month)"
    }

    static func month(_ date: Date) -> String {
        date.formatted(.dateTime.month(.wide).year())
    }

    static func monthName(_ date: Date) -> String {
        date.formatted(.dateTime.month(.wide))
    }

    static func short(_ date: Date) -> String {
        date.formatted(.dateTime.month(.abbreviated).day())
    }

    static func long(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .omitted)
    }

    /// "Today", "Yesterday", "Tomorrow", or "Mon, Oct 20".
    static func relativeDay(_ date: Date, calendar: Calendar = .current, now: Date = Date()) -> String {
        if calendar.isDate(date, inSameDayAs: now) { return "Today" }
        let distance = calendar.daysFromToday(to: date, now: now)
        if distance == -1 { return "Yesterday" }
        if distance == 1 { return "Tomorrow" }
        if calendar.isDate(date, equalTo: now, toGranularity: .year) {
            return date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
        }
        return date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day().year())
    }

    /// "today", "tomorrow", "in 5 days", "3 days ago".
    static func dueText(_ date: Date, calendar: Calendar = .current, now: Date = Date()) -> String {
        let days = calendar.daysFromToday(to: date, now: now)
        switch days {
        case 0: return "today"
        case 1: return "tomorrow"
        case -1: return "yesterday"
        case let value where value > 1: return "in \(value) days"
        default: return "\(-days) days ago"
        }
    }

    static func greeting(now: Date = Date(), calendar: Calendar = .current) -> String {
        let hour = calendar.component(.hour, from: now)
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<22: return "Good evening"
        default: return "Hello, night owl"
        }
    }
}

// MARK: - Budgets

enum BudgetResolver {
    /// Starter plan. Categories without a default stay unbudgeted until the user sets a limit.
    static let defaults: [LedgerCategory: Int] = [
        .groceries: 55_000, .dining: 20_000, .transport: 16_000, .shopping: 25_000,
        .bills: 140_000, .health: 12_000, .leisure: 12_000, .other: 10_000,
    ]

    struct Record {
        let monthKey: String
        let category: LedgerCategory
        let cents: Int
    }

    /// Each category uses the most recent limit set in or before `monthKey`,
    /// falling back to the default plan. A negative record removes the budget.
    static func limits(forMonthKey monthKey: String, records: [Record]) -> [LedgerCategory: Int] {
        var result = defaults
        for category in LedgerCategory.expenseCases {
            let latest = records
                .filter { $0.category == category && $0.monthKey <= monthKey }
                .max { $0.monthKey < $1.monthKey }
            guard let latest else { continue }
            if latest.cents < 0 {
                result.removeValue(forKey: category)
            } else {
                result[category] = latest.cents
            }
        }
        return result
    }

    static func limits(for month: Date, budgets: [BudgetLimit]) -> [LedgerCategory: Int] {
        limits(forMonthKey: DateText.monthKey(month),
               records: budgets.map { Record(monthKey: $0.monthKey, category: $0.category, cents: $0.limitCents) })
    }
}

// MARK: - Month summary

/// Totals for one calendar month, computed once so views can read them cheaply.
struct MonthSummary {
    let month: Date
    /// Newest first.
    let entries: [LedgerEntry]
    let limits: [LedgerCategory: Int]
    let income: Int
    let expenses: Int
    /// Expenses that came from recurring rules (rent, subscriptions…).
    let recurringExpenses: Int
    let daysInMonth: Int
    private let spentByCategory: [LedgerCategory: Int]
    private let earnedByCategory: [LedgerCategory: Int]
    /// Index 0 is day 1.
    let dailySpending: [Int]
    private let calendar: Calendar

    init(month: Date, allEntries: [LedgerEntry], budgets: [BudgetLimit], calendar: Calendar = .current) {
        let start = calendar.startOfMonth(for: month)
        let end = calendar.month(offset: 1, from: start)
        let days = calendar.daysInMonth(of: start)
        self.month = start
        self.calendar = calendar
        self.daysInMonth = days

        let inMonth = allEntries
            .filter { $0.date >= start && $0.date < end }
            .sorted { $0.date == $1.date ? $0.title < $1.title : $0.date > $1.date }
        self.entries = inMonth
        self.limits = BudgetResolver.limits(for: start, budgets: budgets)

        var income = 0, expenses = 0, recurring = 0
        var spent: [LedgerCategory: Int] = [:]
        var earned: [LedgerCategory: Int] = [:]
        var daily = Array(repeating: 0, count: days)
        for entry in inMonth {
            if entry.kind == .income {
                income += entry.amountCents
                earned[entry.category, default: 0] += entry.amountCents
            } else {
                expenses += entry.amountCents
                spent[entry.category, default: 0] += entry.amountCents
                if entry.ruleID != nil { recurring += entry.amountCents }
                let day = calendar.component(.day, from: entry.date)
                if day >= 1 && day <= days { daily[day - 1] += entry.amountCents }
            }
        }
        self.income = income
        self.expenses = expenses
        self.recurringExpenses = recurring
        self.spentByCategory = spent
        self.earnedByCategory = earned
        self.dailySpending = daily
    }

    var net: Int { income - expenses }
    var budget: Int { limits.values.reduce(0, +) }
    var remaining: Int { budget - budgetedSpending }
    var hasBudget: Bool { !limits.isEmpty }
    var expenseEntries: [LedgerEntry] { entries.filter { $0.kind == .expense } }
    var incomeEntries: [LedgerEntry] { entries.filter { $0.kind == .income } }

    /// Spending in categories that have a budget, so the plan compares like with like.
    var budgetedSpending: Int {
        limits.keys.reduce(0) { $0 + spent($1) }
    }

    /// Share of income kept this month (0–1), or nil without income.
    var savingsRate: Double? {
        guard income > 0 else { return nil }
        return Double(income - expenses) / Double(income)
    }

    func total(_ kind: EntryKind) -> Int { kind == .income ? income : expenses }
    func spent(_ category: LedgerCategory) -> Int { spentByCategory[category] ?? 0 }
    func earned(_ category: LedgerCategory) -> Int { earnedByCategory[category] ?? 0 }
    func limit(_ category: LedgerCategory) -> Int? { limits[category] }

    func spent(on day: Date) -> Int {
        guard calendar.isDate(day, equalTo: month, toGranularity: .month) else { return 0 }
        let index = calendar.component(.day, from: day) - 1
        return dailySpending.indices.contains(index) ? dailySpending[index] : 0
    }

    var rankedCategories: [LedgerCategory] {
        LedgerCategory.expenseCases.filter { spent($0) > 0 }.sorted { spent($0) > spent($1) }
    }

    var rankedIncomeCategories: [LedgerCategory] {
        LedgerCategory.incomeCases.filter { earned($0) > 0 }.sorted { earned($0) > earned($1) }
    }

    var overBudgetCategories: [LedgerCategory] {
        limits.keys.filter { spent($0) > (limits[$0] ?? 0) }
            .sorted { $0.label < $1.label }
    }

    /// Days counted for averages: all days for past months, days so far for the current month.
    func elapsedDays(today: Date) -> Int {
        let currentMonth = calendar.startOfMonth(for: today)
        if month > currentMonth { return 0 }
        if month == currentMonth { return calendar.component(.day, from: today) }
        return daysInMonth
    }

    func isCurrentMonth(today: Date = Date()) -> Bool {
        calendar.isDate(month, equalTo: today, toGranularity: .month)
    }

    /// Running total of spending, one value per day of the month.
    var cumulativeSpending: [Int] {
        var running = 0
        return dailySpending.map { value in
            running += value
            return running
        }
    }
}

// MARK: - CSV export

enum CSVExport {
    /// Quotes a cell and neutralizes text a spreadsheet could run as a formula.
    static func cell(_ text: String) -> String {
        let risky = text.range(of: #"^[\s]*[=+@\-\t\r]"#, options: .regularExpression) != nil
        let safe = risky ? "'" + text : text
        return "\"" + safe.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    static func make(entries: [LedgerEntry], currency: CurrencyCode) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        var lines = ["Date,Description,Type,Category,Amount,Currency,Note,Recurring"]
        for entry in entries.sorted(by: { $0.date < $1.date }) {
            lines.append([
                formatter.string(from: entry.date),
                cell(entry.title),
                entry.kind.rawValue,
                cell(entry.category.label),
                Money.inputText(entry.amountCents),
                currency.rawValue,
                cell(entry.note),
                entry.ruleID == nil ? "no" : "yes",
            ].joined(separator: ","))
        }
        return lines.joined(separator: "\r\n")
    }

    /// Writes the CSV to a temporary file so it can be shared or saved to Files.
    static func file(entries: [LedgerEntry], currency: CurrencyCode, name: String) -> URL? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        do {
            try make(entries: entries, currency: currency).write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            return nil
        }
    }
}
