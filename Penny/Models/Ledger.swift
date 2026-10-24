import Foundation
import SwiftData
import SwiftUI

// MARK: - Value types

enum EntryKind: String, Codable, CaseIterable, Identifiable {
    case expense
    case income

    var id: String { rawValue }
    var label: String { self == .expense ? "Expense" : "Income" }
    var symbol: String { self == .expense ? "arrow.up.right" : "arrow.down.left" }
}

/// Named `LedgerCategory` (not `Category`) so it never collides with
/// framework types of the same name. Raw values are stored, so existing
/// cases must never be renamed.
enum LedgerCategory: String, Codable, CaseIterable, Identifiable {
    // Expenses
    case groceries, dining, transport, shopping, bills, health, leisure
    case travel, education, subscriptions, gifts, personal, pets, other
    // Income. `income` keeps its original raw value so older entries read as salary.
    case income, business, investments, refunds, otherIncome

    var id: String { rawValue }

    static let incomeCases: [LedgerCategory] = [.income, .business, .investments, .refunds, .otherIncome]
    static var expenseCases: [LedgerCategory] { allCases.filter { !$0.isIncome } }

    static func cases(for kind: EntryKind) -> [LedgerCategory] {
        kind == .income ? incomeCases : expenseCases
    }

    /// Keeps a category consistent with the entry type.
    static func normalized(_ category: LedgerCategory, for kind: EntryKind) -> LedgerCategory {
        switch kind {
        case .income: return category.isIncome ? category : .income
        case .expense: return category.isIncome ? .other : category
        }
    }

    var isIncome: Bool { Self.incomeCases.contains(self) }

    var label: String {
        switch self {
        case .groceries: return "Groceries"
        case .dining: return "Food & drink"
        case .transport: return "Transport"
        case .shopping: return "Shopping"
        case .bills: return "Bills & home"
        case .health: return "Health"
        case .leisure: return "Leisure"
        case .travel: return "Travel"
        case .education: return "Education"
        case .subscriptions: return "Subscriptions"
        case .gifts: return "Gifts & giving"
        case .personal: return "Personal care"
        case .pets: return "Pets"
        case .other: return "Other"
        case .income: return "Salary"
        case .business: return "Business"
        case .investments: return "Investments"
        case .refunds: return "Refunds"
        case .otherIncome: return "Other income"
        }
    }

    var symbol: String {
        switch self {
        case .groceries: return "cart.fill"
        case .dining: return "fork.knife"
        case .transport: return "car.fill"
        case .shopping: return "bag.fill"
        case .bills: return "house.fill"
        case .health: return "cross.case.fill"
        case .leisure: return "ticket.fill"
        case .travel: return "airplane"
        case .education: return "graduationcap.fill"
        case .subscriptions: return "play.rectangle.fill"
        case .gifts: return "gift.fill"
        case .personal: return "sparkles"
        case .pets: return "pawprint.fill"
        case .other: return "square.grid.2x2.fill"
        case .income: return "briefcase.fill"
        case .business: return "building.2.fill"
        case .investments: return "chart.line.uptrend.xyaxis"
        case .refunds: return "arrow.uturn.backward.circle.fill"
        case .otherIncome: return "plus.circle.fill"
        }
    }

    private var hex: (light: UInt32, dark: UInt32) {
        switch self {
        case .groceries: return (0x0E9F6E, 0x34D399)
        case .dining: return (0xEA580C, 0xFB923C)
        case .transport: return (0x2563EB, 0x60A5FA)
        case .shopping: return (0xDB2777, 0xF472B6)
        case .bills: return (0x0891B2, 0x22D3EE)
        case .health: return (0xDC2626, 0xF87171)
        case .leisure: return (0x7C3AED, 0xA78BFA)
        case .travel: return (0x0284C7, 0x38BDF8)
        case .education: return (0x4F46E5, 0x818CF8)
        case .subscriptions: return (0xC026D3, 0xE879F9)
        case .gifts: return (0xE11D48, 0xFB7185)
        case .personal: return (0xD97706, 0xFBBF24)
        case .pets: return (0x9A5B13, 0xD6A06B)
        case .other: return (0x64748B, 0x94A3B8)
        case .income: return (0x15803D, 0x4ADE80)
        case .business: return (0x0F766E, 0x2DD4BF)
        case .investments: return (0x4D7C0F, 0xA3E635)
        case .refunds: return (0x0369A1, 0x7DD3FC)
        case .otherIncome: return (0x047857, 0x6EE7B7)
        }
    }

    var color: Color { Color.dynamic(light: hex.light, dark: hex.dark) }
}

enum RepeatFrequency: String, Codable, CaseIterable, Identifiable {
    case weekly, biweekly, monthly, quarterly, yearly

    var id: String { rawValue }

    var label: String {
        switch self {
        case .weekly: return "Every week"
        case .biweekly: return "Every 2 weeks"
        case .monthly: return "Every month"
        case .quarterly: return "Every 3 months"
        case .yearly: return "Every year"
        }
    }

    var shortLabel: String {
        switch self {
        case .weekly: return "Weekly"
        case .biweekly: return "Biweekly"
        case .monthly: return "Monthly"
        case .quarterly: return "Quarterly"
        case .yearly: return "Yearly"
        }
    }

    /// Occurrences per month, used to show a normalized monthly cost.
    var perMonth: Double {
        switch self {
        case .weekly: return 52.0 / 12.0
        case .biweekly: return 26.0 / 12.0
        case .monthly: return 1
        case .quarterly: return 1.0 / 3.0
        case .yearly: return 1.0 / 12.0
        }
    }

    /// Date of the n-th occurrence counted from the start date (occurrence 0 = start).
    /// Counting from the start avoids drift, e.g. Jan 31 -> Feb 28 -> Mar 31.
    func date(occurrence: Int, from start: Date, calendar: Calendar = .current) -> Date {
        let result: Date?
        switch self {
        case .weekly: result = calendar.date(byAdding: .day, value: 7 * occurrence, to: start)
        case .biweekly: result = calendar.date(byAdding: .day, value: 14 * occurrence, to: start)
        case .monthly: result = calendar.date(byAdding: .month, value: occurrence, to: start)
        case .quarterly: result = calendar.date(byAdding: .month, value: 3 * occurrence, to: start)
        case .yearly: result = calendar.date(byAdding: .year, value: occurrence, to: start)
        }
        return result ?? start
    }
}

enum CurrencyCode: String, CaseIterable, Identifiable {
    case usd = "USD", jmd = "JMD", eur = "EUR", gbp = "GBP", cad = "CAD", aud = "AUD"
    case ttd = "TTD", bsd = "BSD", bbd = "BBD", xcd = "XCD", mxn = "MXN", inr = "INR"
    case ngn = "NGN", zar = "ZAR", chf = "CHF", nzd = "NZD"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .usd: return "$"
        case .jmd: return "J$"
        case .eur: return "€"
        case .gbp: return "£"
        case .cad: return "CA$"
        case .aud: return "A$"
        case .ttd: return "TT$"
        case .bsd: return "B$"
        case .bbd: return "Bds$"
        case .xcd: return "EC$"
        case .mxn: return "MX$"
        case .inr: return "₹"
        case .ngn: return "₦"
        case .zar: return "R"
        case .chf: return "CHF "
        case .nzd: return "NZ$"
        }
    }

    var name: String {
        switch self {
        case .usd: return "US dollar"
        case .jmd: return "Jamaican dollar"
        case .eur: return "Euro"
        case .gbp: return "British pound"
        case .cad: return "Canadian dollar"
        case .aud: return "Australian dollar"
        case .ttd: return "Trinidad & Tobago dollar"
        case .bsd: return "Bahamian dollar"
        case .bbd: return "Barbadian dollar"
        case .xcd: return "East Caribbean dollar"
        case .mxn: return "Mexican peso"
        case .inr: return "Indian rupee"
        case .ngn: return "Nigerian naira"
        case .zar: return "South African rand"
        case .chf: return "Swiss franc"
        case .nzd: return "New Zealand dollar"
        }
    }
}

/// Colors a savings goal can use.
enum GoalColor: String, CaseIterable, Identifiable, Codable {
    case lime, mint, ocean, violet, sunset, rose, gold

    var id: String { rawValue }

    var colors: [Color] {
        switch self {
        case .lime: return [Color(hex: 0xD8F36A), Color(hex: 0x7FC52A)]
        case .mint: return [Color(hex: 0x6EE7B7), Color(hex: 0x0E9F6E)]
        case .ocean: return [Color(hex: 0x7DD3FC), Color(hex: 0x2563EB)]
        case .violet: return [Color(hex: 0xC4B5FD), Color(hex: 0x7C3AED)]
        case .sunset: return [Color(hex: 0xFDBA74), Color(hex: 0xEA580C)]
        case .rose: return [Color(hex: 0xFDA4AF), Color(hex: 0xE11D48)]
        case .gold: return [Color(hex: 0xFDE68A), Color(hex: 0xD97706)]
        }
    }

    var main: Color { colors[1] }
    var gradient: LinearGradient {
        LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

// MARK: - Stored models (SwiftData)
// New properties always have defaults so existing stores migrate automatically.

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
    @Attribute(.externalStorage) var receiptData: Data?
    /// Kept alongside `receiptData` so lists can show a paperclip without loading the image.
    var hasReceipt: Bool = false

    init(title: String, amountCents: Int, kind: EntryKind, category: LedgerCategory,
         date: Date, note: String = "", isSample: Bool = false, ruleID: UUID? = nil,
         receiptData: Data? = nil) {
        self.id = UUID()
        self.title = title
        self.amountCents = amountCents
        self.kindRaw = kind.rawValue
        self.categoryRaw = LedgerCategory.normalized(category, for: kind).rawValue
        self.date = date
        self.note = note
        self.isSample = isSample
        self.ruleID = ruleID
        self.receiptData = receiptData
        self.hasReceipt = receiptData != nil
    }

    func setReceipt(_ data: Data?) {
        receiptData = data
        hasReceipt = data != nil
    }

    var kind: EntryKind {
        get { EntryKind(rawValue: kindRaw) ?? .expense }
        set { kindRaw = newValue.rawValue }
    }

    var category: LedgerCategory {
        get { LedgerCategory(rawValue: categoryRaw) ?? (kind == .income ? .income : .other) }
        set { categoryRaw = newValue.rawValue }
    }

    /// Positive for income, negative for expenses.
    var signedCents: Int { kind == .income ? amountCents : -amountCents }
}

/// A category limit that applies from `monthKey` (yyyy-MM) onward,
/// until a later month sets its own limit. A negative limit means
/// "no budget from this month on".
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
    var isSample: Bool = false

    init(title: String, amountCents: Int, kind: EntryKind, category: LedgerCategory,
         note: String, frequency: RepeatFrequency, startDate: Date, generatedCount: Int = 0) {
        self.id = UUID()
        self.title = title
        self.amountCents = amountCents
        self.kindRaw = kind.rawValue
        self.categoryRaw = LedgerCategory.normalized(category, for: kind).rawValue
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
        get { LedgerCategory(rawValue: categoryRaw) ?? (kind == .income ? .income : .other) }
        set { categoryRaw = newValue.rawValue }
    }

    var frequency: RepeatFrequency {
        get { RepeatFrequency(rawValue: frequencyRaw) ?? .monthly }
        set { frequencyRaw = newValue.rawValue }
    }

    var nextDate: Date { frequency.date(occurrence: generatedCount, from: startDate) }

    /// Approximate monthly amount, e.g. a weekly $10 is about $43.33/month.
    var monthlyCents: Int { Int((Double(amountCents) * frequency.perMonth).rounded()) }

    /// Dates of not-yet-recorded occurrences up to and including `horizon`.
    func upcomingDates(through horizon: Date, limit: Int = 60) -> [Date] {
        guard isActive else { return [] }
        var dates: [Date] = []
        var occurrence = generatedCount
        while dates.count < limit {
            let date = frequency.date(occurrence: occurrence, from: startDate)
            if date > horizon { break }
            dates.append(date)
            occurrence += 1
        }
        return dates
    }
}

/// Something the user is saving towards. The saved amount is the sum of its contributions.
@Model
final class SavingsGoal {
    var id: UUID = UUID()
    var name: String = ""
    var targetCents: Int = 0
    var symbol: String = "star.fill"
    var colorRaw: String = GoalColor.lime.rawValue
    var deadline: Date?
    var createdAt: Date = Date()
    var isArchived: Bool = false
    var isSample: Bool = false

    init(name: String, targetCents: Int, symbol: String, color: GoalColor,
         deadline: Date? = nil, isSample: Bool = false) {
        self.id = UUID()
        self.name = name
        self.targetCents = targetCents
        self.symbol = symbol
        self.colorRaw = color.rawValue
        self.deadline = deadline
        self.createdAt = Date()
        self.isArchived = false
        self.isSample = isSample
    }

    var color: GoalColor {
        get { GoalColor(rawValue: colorRaw) ?? .lime }
        set { colorRaw = newValue.rawValue }
    }
}

/// Money added to (positive) or taken out of (negative) a savings goal.
@Model
final class GoalContribution {
    var id: UUID = UUID()
    var goalID: UUID = UUID()
    var amountCents: Int = 0
    var date: Date = Date()
    var note: String = ""

    init(goalID: UUID, amountCents: Int, date: Date = Date(), note: String = "") {
        self.id = UUID()
        self.goalID = goalID
        self.amountCents = amountCents
        self.date = date
        self.note = note
    }
}
