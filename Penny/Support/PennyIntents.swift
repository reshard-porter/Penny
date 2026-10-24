import AppIntents
import Foundation
import SwiftData

// Siri, Spotlight and Shortcuts actions. They run inside Penny's own process,
// so no extension or extra capability is needed (works with a free Apple ID).

enum ExpenseCategoryOption: String, AppEnum {
    case groceries, dining, transport, shopping, bills, health, leisure
    case travel, education, subscriptions, gifts, personal, pets, other

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Category"
    static var caseDisplayRepresentations: [ExpenseCategoryOption: DisplayRepresentation] = [
        .groceries: DisplayRepresentation(title: "Groceries", image: .init(systemName: "cart.fill")),
        .dining: DisplayRepresentation(title: "Dining", image: .init(systemName: "fork.knife")),
        .transport: DisplayRepresentation(title: "Transport", image: .init(systemName: "car.fill")),
        .shopping: DisplayRepresentation(title: "Shopping", image: .init(systemName: "bag.fill")),
        .bills: DisplayRepresentation(title: "Bills & home", image: .init(systemName: "house.fill")),
        .health: DisplayRepresentation(title: "Health", image: .init(systemName: "cross.case.fill")),
        .leisure: DisplayRepresentation(title: "Leisure", image: .init(systemName: "ticket.fill")),
        .travel: DisplayRepresentation(title: "Travel", image: .init(systemName: "airplane")),
        .education: DisplayRepresentation(title: "Education", image: .init(systemName: "graduationcap.fill")),
        .subscriptions: DisplayRepresentation(title: "Subscriptions", image: .init(systemName: "play.rectangle.fill")),
        .gifts: DisplayRepresentation(title: "Gifts & giving", image: .init(systemName: "gift.fill")),
        .personal: DisplayRepresentation(title: "Personal care", image: .init(systemName: "sparkles")),
        .pets: DisplayRepresentation(title: "Pets", image: .init(systemName: "pawprint.fill")),
        .other: DisplayRepresentation(title: "Other", image: .init(systemName: "square.grid.2x2.fill")),
    ]

    var ledgerCategory: LedgerCategory { LedgerCategory(rawValue: rawValue) ?? .other }
}

private enum IntentSupport {
    static var currency: CurrencyCode {
        CurrencyCode(rawValue: UserDefaults.standard.string(forKey: "currency") ?? "") ?? .usd
    }
}

struct LogExpenseIntent: AppIntent {
    static var title: LocalizedStringResource = "Log an Expense"
    static var description = IntentDescription("Adds an expense to Penny without opening the app.")

    @Parameter(title: "Amount", description: "How much you spent")
    var amount: Double

    @Parameter(title: "Description", default: "Expense")
    var label: String

    @Parameter(title: "Category", default: .other)
    var category: ExpenseCategoryOption

    static var parameterSummary: some ParameterSummary {
        Summary("Log \(\.$amount) for \(\.$label) in \(\.$category)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let cents = Money.cents(fromDecimal: amount) else {
            throw $amount.needsValueError("How much did you spend?")
        }
        let title = label.trimmingCharacters(in: .whitespacesAndNewlines)
        let context = PennyStore.container.mainContext
        context.insert(LedgerEntry(title: title.isEmpty ? "Expense" : String(title.prefix(70)),
                                   amountCents: cents, kind: .expense,
                                   category: category.ledgerCategory, date: Date()))
        try context.save()
        let message = "Logged \(Money.format(cents, currency: IntentSupport.currency)) for \(title.isEmpty ? "an expense" : title)."
        return .result(dialog: IntentDialog(stringLiteral: message))
    }
}

struct LogIncomeIntent: AppIntent {
    static var title: LocalizedStringResource = "Log Income"
    static var description = IntentDescription("Adds money you received to Penny.")

    @Parameter(title: "Amount", description: "How much you received")
    var amount: Double

    @Parameter(title: "Description", default: "Income")
    var label: String

    static var parameterSummary: some ParameterSummary {
        Summary("Log \(\.$amount) of income from \(\.$label)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let cents = Money.cents(fromDecimal: amount) else {
            throw $amount.needsValueError("How much did you receive?")
        }
        let title = label.trimmingCharacters(in: .whitespacesAndNewlines)
        let context = PennyStore.container.mainContext
        context.insert(LedgerEntry(title: title.isEmpty ? "Income" : String(title.prefix(70)),
                                   amountCents: cents, kind: .income, category: .otherIncome, date: Date()))
        try context.save()
        let message = "Added \(Money.format(cents, currency: IntentSupport.currency)) of income."
        return .result(dialog: IntentDialog(stringLiteral: message))
    }
}

struct SpendingSummaryIntent: AppIntent {
    static var title: LocalizedStringResource = "Monthly Spending"
    static var description = IntentDescription("Tells you how much you’ve spent this month and what’s left in your plan.")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = PennyStore.container.mainContext
        let calendar = Calendar.current
        let start = calendar.startOfMonth(for: Date())
        let end = calendar.month(offset: 1, from: start)
        let entries = try context.fetch(FetchDescriptor<LedgerEntry>(
            predicate: #Predicate { $0.date >= start && $0.date < end }))
        let budgets = try context.fetch(FetchDescriptor<BudgetLimit>())
        let summary = MonthSummary(month: start, allEntries: entries, budgets: budgets)
        let currency = IntentSupport.currency
        var message = "You’ve spent \(Money.format(summary.expenses, currency: currency)) in \(DateText.monthName(start))."
        if summary.hasBudget {
            if summary.remaining >= 0 {
                message += " \(Money.format(summary.remaining, currency: currency)) is left in your plan."
            } else {
                message += " That’s \(Money.format(-summary.remaining, currency: currency)) over your plan."
            }
        }
        return .result(dialog: IntentDialog(stringLiteral: message))
    }
}

struct OpenNewTransactionIntent: AppIntent {
    static var title: LocalizedStringResource = "New Transaction"
    static var description = IntentDescription("Opens Penny ready to add a transaction.")
    static var openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        AppState.shared.selectedTab = .home
        AppState.shared.editor = .add(.expense)
        return .result()
    }
}

struct PennyShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: LogExpenseIntent(),
                    phrases: ["Log an expense in \(.applicationName)",
                              "Add an expense to \(.applicationName)",
                              "Log spending in \(.applicationName)"],
                    shortTitle: "Log Expense",
                    systemImageName: "minus.circle.fill")
        AppShortcut(intent: LogIncomeIntent(),
                    phrases: ["Log income in \(.applicationName)",
                              "Add income to \(.applicationName)"],
                    shortTitle: "Log Income",
                    systemImageName: "plus.circle.fill")
        AppShortcut(intent: SpendingSummaryIntent(),
                    phrases: ["How much have I spent in \(.applicationName)",
                              "Check my \(.applicationName) budget",
                              "\(.applicationName) spending this month"],
                    shortTitle: "Monthly Spending",
                    systemImageName: "chart.pie.fill")
        AppShortcut(intent: OpenNewTransactionIntent(),
                    phrases: ["New transaction in \(.applicationName)",
                              "Open \(.applicationName) to add a transaction"],
                    shortTitle: "New Transaction",
                    systemImageName: "square.and.pencil")
    }
}
