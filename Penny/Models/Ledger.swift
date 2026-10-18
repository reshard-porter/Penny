import Foundation
import SwiftData
import SwiftUI

// MARK: - Value types

enum EntryKind: String, Codable, CaseIterable, Identifiable {
    case expense
    case income

    var id: String { rawValue }
    var label: String { self == .expense ? "Expense" : "Income" }
}

/// Named `LedgerCategory` (not `Category`) so it never collides with
/// framework types of the same name.
enum LedgerCategory: String, Codable, CaseIterable, Identifiable {
    case groceries, dining, transport, shopping, bills, health, leisure, other, income

    var id: String { rawValue }

    static var expenseCases: [LedgerCategory] { allCases.filter { $0 != .income } }

    var label: String {
        switch self {
        case .groceries: return "Groceries"
        case .dining: return "Food & drink"
        case .transport: return "Transport"
        case .shopping: return "Shopping"
        case .bills: return "Bills & home"
        case .health: return "Health"
        case .leisure: return "Leisure"
        case .other: return "Other"
        case .income: return "Income"
        }
    }

    var symbol: String {
        switch self {
        case .groceries: return "cart"
        case .dining: return "fork.knife"
        case .transport: return "bus"
        case .shopping: return "bag"
        case .bills: return "house"
        case .health: return "heart"
        case .leisure: return "ticket"
        case .other: return "ellipsis.circle"
        case .income: return "arrow.down.left"
        }
    }

    var color: Color {
        switch self {
        case .groceries: return Color.dynamic(light: 0x2549D8, dark: 0x8FA6FF)
        case .dining: return Color.dynamic(light: 0x9A3E10, dark: 0xFFA36E)
        case .transport: return Color.dynamic(light: 0x5C38A0, dark: 0xC4A8FF)
        case .shopping: return Color.dynamic(light: 0x9B225D, dark: 0xFF8FC4)
        case .bills: return Color.dynamic(light: 0x006A76, dark: 0x5FD6E4)
        case .health: return Color.dynamic(light: 0xB42318, dark: 0xFF8A80)
        case .leisure: return Color.dynamic(light: 0x6E5300, dark: 0xE8C35A)
        case .other: return Color.dynamic(light: 0x526078, dark: 0xA9B4C8)
        case .income: return Palette.green
        }
    }
}

enum RepeatFrequency: String, Codable, CaseIterable, Identifiable {
    case weekly, monthly, yearly

    var id: String { rawValue }

    var label: String {
        switch self {
        case .weekly: return "Every week"
        case .monthly: return "Every month"
        case .yearly: return "Every year"
        }
    }

    /// Date of the n-th occurrence counted from the start date (occurrence 0 = start).
    /// Counting from the start avoids drift, e.g. Jan 31 -> Feb 28 -> Mar 31.
    func date(occurrence: Int, from start: Date, calendar: Calendar = .current) -> Date {
        let result: Date?
        switch self {
        case .weekly: result = calendar.date(byAdding: .day, value: 7 * occurrence, to: start)
        case .monthly: result = calendar.date(byAdding: .month, value: occurrence, to: start)
        case .yearly: result = calendar.date(byAdding: .year, value: occurrence, to: start)
        }
        return result ?? start
    }
}

enum CurrencyCode: String, CaseIterable, Identifiable {
    case usd = "USD", jmd = "JMD", eur = "EUR", gbp = "GBP"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .usd: return "$"
        case .jmd: return "J$"
        case .eur: return "€"
        case .gbp: return "£"
        }
    }

    var name: String {
        switch self {
        case .usd: return "US dollar"
        case .jmd: return "Jamaican dollar"
        case .eur: return "Euro"
        case .gbp: return "British pound"
        }
    }
}

// MARK: - Stored models (SwiftData)

@Model
final class LedgerEntry {
    var id: UUID = UUID()
    var title: String = ""
    var amountCents: Int = 0
    var kindRaw: String = EntryKind.expense.rawValue
    var categoryRaw: String = LedgerCategory.other.rawValue
    var date: Date = Date()
    var note: String = ""
    var isSample: Bool = false
    var ruleID: UUID?

    init(title: String, amountCents: Int, kind: EntryKind, category: LedgerCategory,
         date: Date, note: String = "", isSample: Bool = false, ruleID: UUID? = nil) {
        self.id = UUID()
        self.title = title
        self.amountCents = amountCents
        self.kindRaw = kind.rawValue
        self.categoryRaw = (kind == .income ? LedgerCategory.income : category).rawValue
        self.date = date
        self.note = note
        self.isSample = isSample
        self.ruleID = ruleID
    }

    var kind: EntryKind {
        get { EntryKind(rawValue: kindRaw) ?? .expense }
        set { kindRaw = newValue.rawValue }
    }

    var category: LedgerCategory {
        get { LedgerCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }
}

/// A category limit that applies from `monthKey` (yyyy-MM) onward,
/// until a later month sets its own limit.
@Model
final class BudgetLimit {
    var monthKey: String = ""
    var categoryRaw: String = LedgerCategory.other.rawValue
    var limitCents: Int = 0

    init(monthKey: String, category: LedgerCategory, limitCents: Int) {
        self.monthKey = monthKey
        self.categoryRaw = category.rawValue
        self.limitCents = limitCents
    }

    var category: LedgerCategory { LedgerCategory(rawValue: categoryRaw) ?? .other }
}

@Model
final class RecurringRule {
    var id: UUID = UUID()
    var title: String = ""
    var amountCents: Int = 0
    var kindRaw: String = EntryKind.expense.rawValue
    var categoryRaw: String = LedgerCategory.other.rawValue
    var note: String = ""
    var frequencyRaw: String = RepeatFrequency.monthly.rawValue
    var startDate: Date = Date()
    /// How many entries this rule has already created.
    var generatedCount: Int = 0
    var isActive: Bool = true

    init(title: String, amountCents: Int, kind: EntryKind, category: LedgerCategory,
         note: String, frequency: RepeatFrequency, startDate: Date, generatedCount: Int = 0) {
        self.id = UUID()
        self.title = title
        self.amountCents = amountCents
        self.kindRaw = kind.rawValue
        self.categoryRaw = (kind == .income ? LedgerCategory.income : category).rawValue
        self.note = note
        self.frequencyRaw = frequency.rawValue
        self.startDate = startDate
        self.generatedCount = generatedCount
        self.isActive = true
    }

    var kind: EntryKind {
        get { EntryKind(rawValue: kindRaw) ?? .expense }
        set { kindRaw = newValue.rawValue }
    }

    var category: LedgerCategory {
        get { LedgerCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }

    var frequency: RepeatFrequency {
        get { RepeatFrequency(rawValue: frequencyRaw) ?? .monthly }
        set { frequencyRaw = newValue.rawValue }
    }

    var nextDate: Date { frequency.date(occurrence: generatedCount, from: startDate) }
}
