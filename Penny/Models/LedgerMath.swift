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
}

// MARK: - Budgets

enum BudgetResolver {
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
    /// falling back to the default plan.
    static func limits(forMonthKey monthKey: String, records: [Record]) -> [LedgerCategory: Int] {
        var result = defaults
        for category in LedgerCategory.expenseCases {
            let latest = records
                .filter { $0.category == category && $0.monthKey <= monthKey }
                .max { $0.monthKey < $1.monthKey }
            if let latest { result[category] = latest.cents }
        }
        return result
    }

    static func limits(for month: Date, budgets: [BudgetLimit]) -> [LedgerCategory: Int] {
        limits(forMonthKey: DateText.monthKey(month),
               records: budgets.map { Record(monthKey: $0.monthKey, category: $0.category, cents: $0.limitCents) })
    }
}

// MARK: - Month summary

struct MonthSummary {
    let month: Date
    let entries: [LedgerEntry]
    let limits: [LedgerCategory: Int]
    private let calendar: Calendar

    init(month: Date, allEntries: [LedgerEntry], budgets: [BudgetLimit], calendar: Calendar = .current) {
        let start = calendar.startOfMonth(for: month)
        self.month = start
        self.calendar = calendar
        self.entries = allEntries
            .filter { calendar.isDate($0.date, equalTo: start, toGranularity: .month) }
            .sorted { $0.date == $1.date ? $0.title < $1.title : $0.date > $1.date }
        self.limits = BudgetResolver.limits(for: start, budgets: budgets)
    }

    var income: Int { total(.income) }
    var expenses: Int { total(.expense) }
    var net: Int { income - expenses }
    var budget: Int { limits.values.reduce(0, +) }
    var remaining: Int { budget - expenses }
    var expenseEntries: [LedgerEntry] { entries.filter { $0.kind == .expense } }

    func total(_ kind: EntryKind) -> Int {
        entries.filter { $0.kind == kind }.reduce(0) { $0 + $1.amountCents }
    }

    func spent(_ category: LedgerCategory) -> Int {
        expenseEntries.filter { $0.category == category }.reduce(0) { $0 + $1.amountCents }
    }

    func spent(on day: Date) -> Int {
        expenseEntries.filter { calendar.isDate($0.date, inSameDayAs: day) }.reduce(0) { $0 + $1.amountCents }
    }

    func limit(_ category: LedgerCategory) -> Int { limits[category] ?? 0 }

    var rankedCategories: [LedgerCategory] {
        LedgerCategory.expenseCases
            .filter { spent($0) > 0 }
            .sorted { spent($0) > spent($1) }
    }

    var daysInMonth: Int { calendar.daysInMonth(of: month) }

    /// Days counted for averages: all days for past months, days so far for the current month.
    func elapsedDays(today: Date) -> Int {
        let currentMonth = calendar.startOfMonth(for: today)
        if month > currentMonth { return 0 }
        if month == currentMonth { return calendar.component(.day, from: today) }
        return daysInMonth
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
        var lines = ["Date,Description,Type,Category,Amount,Currency,Note"]
        for entry in entries.sorted(by: { $0.date < $1.date }) {
            lines.append([
                formatter.string(from: entry.date),
                cell(entry.title),
                entry.kind.rawValue,
                cell(entry.category.label),
                Money.inputText(entry.amountCents),
                currency.rawValue,
                cell(entry.note),
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
