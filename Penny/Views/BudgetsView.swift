import SwiftData
import SwiftUI

struct BudgetsView: View {
    @Environment(AppState.self) private var state
    @Query private var entries: [LedgerEntry]
    @Query private var budgets: [BudgetLimit]
    @AppStorage("currency") private var currencyRaw = CurrencyCode.usd.rawValue
    @State private var editing: LedgerCategory?

    private var currency: CurrencyCode { CurrencyCode(rawValue: currencyRaw) ?? .usd }

    var body: some View {
        let summary = MonthSummary(month: state.selectedMonth, allEntries: entries, budgets: budgets)
        let overCount = LedgerCategory.expenseCases.filter { summary.spent($0) > summary.limit($0) }.count

        ScrollView {
            VStack(spacing: 16) {
                MonthSwitcher()
                VStack(alignment: .leading, spacing: 10) {
                    Text("A PLAN THAT FITS YOUR LIFE")
                        .font(.caption2.weight(.bold)).tracking(1.4)
                        .foregroundStyle(Palette.lime)
                    Text(Money.format(summary.budget, currency: currency))
                        .font(.system(size: 38, weight: .heavy, design: .rounded).monospacedDigit())
                        .foregroundStyle(.white)
                        .minimumScaleFactor(0.5).lineLimit(1)
                    Text("Total planned across your categories")
                        .font(.subheadline).foregroundStyle(Palette.heroText)
                    Text(overCount == 0
                         ? "Every category is within its limit."
                         : "\(overCount) \(overCount == 1 ? "category needs" : "categories need") a little attention.")
                        .font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                        .padding(.top, 4)
                }
                .card(padding: 22, fill: Palette.navy, bordered: false)

                Text("Tap a category to change its limit. A new limit applies from this month onward.")
                    .font(.footnote).foregroundStyle(Palette.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 12)], spacing: 12) {
                    ForEach(LedgerCategory.expenseCases) { category in
                        Button { editing = category } label: {
                            BudgetCard(category: category, spent: summary.spent(category),
                                       limit: summary.limit(category), currency: currency)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding()
        }
        .background(Palette.background)
        .navigationTitle("Budgets")
        .sheet(item: $editing) { category in
            BudgetEditor(category: category, month: state.selectedMonth,
                         currentLimit: summary.limit(category), currency: currency)
                .presentationDetents([.medium])
        }
    }
}

struct BudgetCard: View {
    let category: LedgerCategory
    let spent: Int
    let limit: Int
    let currency: CurrencyCode

    var body: some View {
        let over = spent > limit
        let remaining = limit - spent
        let ratio = limit == 0 ? (spent > 0 ? 1 : 0) : Double(spent) / Double(limit)
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                CategoryBadge(category: category)
                Text(category.label).font(.headline).foregroundStyle(Palette.ink)
                Spacer()
                Text("Edit").font(.subheadline.weight(.bold)).foregroundStyle(Palette.blue)
            }
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(Money.format(spent, currency: currency))
                    .font(.title3.weight(.bold).monospacedDigit()).foregroundStyle(Palette.ink)
                Text("of \(Money.format(limit, currency: currency))")
                    .font(.footnote).foregroundStyle(Palette.muted)
            }
            ProgressBar(value: ratio, tint: over ? Palette.red : category.color)
            Label(over ? "\(Money.format(-remaining, currency: currency)) over your limit"
                       : "\(Money.format(remaining, currency: currency)) left to spend",
                  systemImage: over ? "exclamationmark.circle" : "checkmark.circle")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(over ? Palette.red : Palette.green)
        }
        .card()
        .accessibilityElement(children: .combine)
        .accessibilityHint("Double tap to edit this budget")
    }
}

struct BudgetEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var state
    @Query private var budgets: [BudgetLimit]

    let category: LedgerCategory
    let month: Date
    let currentLimit: Int
    let currency: CurrencyCode

    @State private var text = ""
    @State private var showError = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 8) {
                        Text(currency.symbol).font(.title2.weight(.bold)).foregroundStyle(Palette.muted)
                        TextField("0.00", text: $text)
                            .keyboardType(.decimalPad)
                            .font(.title.weight(.heavy).monospacedDigit())
                            .accessibilityLabel("Monthly limit")
                    }
                    if showError {
                        Text("Use 0 to 9,999,999.99, with up to 2 decimals.")
                            .font(.footnote).foregroundStyle(Palette.red)
                    }
                } header: {
                    Text("Monthly limit from \(DateText.month(month))")
                } footer: {
                    Text("Use 0 for a zero-spend goal.")
                }
            }
            .navigationTitle("\(category.label) budget")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save", action: save).fontWeight(.bold) }
            }
            .onAppear { text = Money.inputText(currentLimit) }
        }
        .lockGuard()
    }

    private func save() {
        guard let cents = Money.parse(text, allowZero: true) else {
            showError = true
            return
        }
        let key = DateText.monthKey(month)
        if let existing = budgets.first(where: { $0.monthKey == key && $0.category == category }) {
            existing.limitCents = cents
        } else {
            context.insert(BudgetLimit(monthKey: key, category: category, limitCents: cents))
        }
        try? context.save()
        state.show("\(category.label) budget saved.")
        dismiss()
    }
}
