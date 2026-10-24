import SwiftData
import SwiftUI

/// Budgets and savings goals, side by side.
struct PlanView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        @Bindable var state = state
        ScrollView {
            VStack(spacing: 18) {
                PillPicker(options: PlanSegment.allCases.map { ($0, $0.label) }, selection: $state.planSegment)
                switch state.planSegment {
                case .budgets: BudgetsSection()
                case .goals: GoalsSection()
                }
            }
            .padding(.horizontal)
            .padding(.top, 4)
            .padding(.bottom, 40)
        }
        .pennyBackground()
        .navigationTitle("Plan")
    }
}

// MARK: - Budgets

struct BudgetsSection: View {
    @Environment(AppState.self) private var state
    @Query private var entries: [LedgerEntry]
    @Query private var budgets: [BudgetLimit]
    @AppStorage("currency") private var currencyRaw = CurrencyCode.usd.rawValue
    @State private var editing: LedgerCategory?

    private var currency: CurrencyCode { CurrencyCode(rawValue: currencyRaw) ?? .usd }

    var body: some View {
        let calendar = Calendar.current
        let summary = MonthSummary(month: state.selectedMonth, allEntries: entries, budgets: budgets)
        let history = (1...3).map {
            MonthSummary(month: calendar.month(offset: -$0, from: state.selectedMonth), allEntries: entries, budgets: budgets)
        }
        let budgeted = summary.limits.keys.sorted { lhs, rhs in
            ratio(summary, lhs) == ratio(summary, rhs) ? lhs.label < rhs.label : ratio(summary, lhs) > ratio(summary, rhs)
        }
        let unbudgeted = summary.rankedCategories.filter { summary.limit($0) == nil }
        let available = LedgerCategory.expenseCases.filter { summary.limit($0) == nil }

        VStack(spacing: 16) {
            MonthSwitcher()
            planHero(summary)

            if budgeted.isEmpty {
                EmptyStateCard(symbol: "chart.pie", title: "No budgets yet",
                               message: "Give a category a monthly limit and Penny tracks it for you.",
                               actionTitle: "Add a budget") { editing = available.first ?? .groceries }
                    .card()
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 320), spacing: 12)], spacing: 12) {
                    ForEach(budgeted) { category in
                        Button {
                            Haptics.tap()
                            editing = category
                        } label: {
                            BudgetCard(category: category, spent: summary.spent(category),
                                       limit: summary.limit(category) ?? 0, summary: summary, currency: currency)
                        }
                        .buttonStyle(PressableStyle())
                    }
                }
            }

            if !unbudgeted.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(title: "Not budgeted", subtitle: "Spending in categories without a limit")
                    ForEach(unbudgeted) { category in
                        HStack(spacing: 12) {
                            CategoryBadge(category: category, size: 38)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(category.label).font(.subheadline.weight(.semibold)).foregroundStyle(Palette.ink)
                                Text("\(Money.format(summary.spent(category), currency: currency)) spent")
                                    .font(.caption).foregroundStyle(Palette.muted)
                            }
                            Spacer()
                            Button("Set limit") { editing = category }
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(Palette.blue)
                                .padding(.horizontal, 12).padding(.vertical, 7)
                                .background(Palette.paleBlue, in: Capsule())
                        }
                    }
                }
                .card()
            }

            Text("Tap a budget to change it. A new limit applies from \(DateText.month(summary.month)) onward.")
                .font(.footnote).foregroundStyle(Palette.muted)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    ForEach(available) { category in
                        Button { editing = category } label: { Label(category.label, systemImage: category.symbol) }
                    }
                } label: {
                    Label("Add budget", systemImage: "plus.circle.fill")
                }
                .disabled(available.isEmpty)
            }
        }
        .sheet(item: $editing) { category in
            let spentHistory = history.map { $0.spent(category) }
            BudgetEditor(category: category, month: state.selectedMonth,
                         currentLimit: summary.limit(category), currency: currency,
                         lastMonth: spentHistory.first ?? 0,
                         average: spentHistory.reduce(0, +) / max(spentHistory.count, 1))
                .presentationDetents([.medium, .large])
                .presentationCornerRadius(28)
        }
    }

    private func ratio(_ summary: MonthSummary, _ category: LedgerCategory) -> Double {
        let limit = summary.limit(category) ?? 0
        let spent = summary.spent(category)
        if limit == 0 { return spent > 0 ? 9 : 0 }
        return Double(spent) / Double(limit)
    }

    private func planHero(_ summary: MonthSummary) -> some View {
        let used = summary.budget == 0 ? 0 : Double(summary.budgetedSpending) / Double(summary.budget)
        let overCount = summary.overBudgetCategories.count
        return HStack(spacing: 20) {
            ZStack {
                RingProgress(value: used, lineWidth: 14, track: Palette.heroTrack)
                VStack(spacing: 0) {
                    Text("\(Int((used * 100).rounded()))%")
                        .font(Typography.money(26, weight: .heavy))
                        .foregroundStyle(.white)
                    Text("used").font(.caption2.weight(.semibold)).foregroundStyle(Palette.heroText)
                }
            }
            .frame(width: 112, height: 112)

            VStack(alignment: .leading, spacing: 8) {
                Eyebrow(text: "Monthly plan")
                Text(Money.short(summary.budget, currency: currency))
                    .font(Typography.money(32, weight: .heavy))
                    .foregroundStyle(.white)
                    .lineLimit(1).minimumScaleFactor(0.5)
                Text(summary.remaining >= 0
                     ? "\(Money.short(summary.remaining, currency: currency)) left to spend"
                     : "\(Money.short(-summary.remaining, currency: currency)) over plan")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(summary.remaining >= 0 ? Palette.lime : Color(hex: 0xFF8A7A))
                Label(overCount == 0 ? "All categories on track"
                                     : "\(overCount) \(overCount == 1 ? "category" : "categories") over",
                      systemImage: overCount == 0 ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Palette.heroText)
            }
            Spacer(minLength: 0)
        }
        .heroCard()
        .accessibilityElement(children: .combine)
    }
}

struct BudgetCard: View {
    let category: LedgerCategory
    let spent: Int
    let limit: Int
    let summary: MonthSummary
    let currency: CurrencyCode

    var body: some View {
        let over = spent > limit
        let remaining = limit - spent
        let ratio = limit == 0 ? (spent > 0 ? 1 : 0) : Double(spent) / Double(limit)
        let isCurrent = summary.isCurrentMonth()
        let pace = Double(summary.elapsedDays(today: Date())) / Double(max(summary.daysInMonth, 1))
        let daysLeft = isCurrent ? summary.daysInMonth - Calendar.current.component(.day, from: Date()) + 1 : 0

        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                CategoryBadge(category: category, size: 42)
                VStack(alignment: .leading, spacing: 2) {
                    Text(category.label).font(.headline).foregroundStyle(Palette.ink)
                    Text(limit == 0 ? "Zero-spend goal" : "\(Money.short(limit, currency: currency)) a month")
                        .font(.caption).foregroundStyle(Palette.muted)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(Money.format(abs(remaining), currency: currency))
                        .font(Typography.money(17, weight: .bold))
                        .foregroundStyle(over ? Palette.red : Palette.ink)
                    Text(over ? "over" : "left")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(over ? Palette.red : Palette.muted)
                }
            }
            ProgressBar(value: ratio,
                        tint: over ? AnyShapeStyle(Gradients.danger) : AnyShapeStyle(Gradients.tint(category.color)),
                        track: Palette.surfaceRaised, height: 10,
                        marker: isCurrent && limit > 0 ? pace : nil)
            HStack {
                Text("\(Money.format(spent, currency: currency)) spent")
                Spacer()
                if over {
                    Label("Over limit", systemImage: "exclamationmark.circle.fill").foregroundStyle(Palette.red)
                } else if isCurrent && daysLeft > 0 && remaining > 0 {
                    Text("≈ \(Money.short(remaining / daysLeft, currency: currency))/day")
                } else {
                    Text("\(Int((ratio * 100).rounded()))% used")
                }
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(Palette.muted)
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
    @FocusState private var focused: Bool

    let category: LedgerCategory
    let month: Date
    let currentLimit: Int?
    let currency: CurrencyCode
    let lastMonth: Int
    let average: Int

    @State private var text = ""
    @State private var showError = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    CategoryBadge(category: category, size: 64)
                        .padding(.top, 8)
                    VStack(spacing: 6) {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(currency.symbol)
                                .font(Typography.money(30, weight: .bold))
                                .foregroundStyle(Palette.muted)
                            TextField("0", text: $text)
                                .keyboardType(.decimalPad)
                                .font(Typography.money(48, weight: .heavy))
                                .foregroundStyle(Palette.ink)
                                .fixedSize()
                                .focused($focused)
                                .accessibilityLabel("Monthly limit")
                        }
                        Text("per month, from \(DateText.month(month))")
                            .font(.subheadline).foregroundStyle(Palette.muted)
                        if showError {
                            Text("Use 0 to 9,999,999.99, with up to 2 decimals.")
                                .font(.footnote).foregroundStyle(Palette.red)
                        }
                    }

                    if lastMonth > 0 || average > 0 {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Suggestions").font(.footnote.weight(.semibold)).foregroundStyle(Palette.muted)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    if lastMonth > 0 { suggestion("Last month", lastMonth) }
                                    if average > 0 { suggestion("3-month avg", average) }
                                    if average > 0 { suggestion("Trim 10%", average * 9 / 10) }
                                }
                            }
                            .scrollClipDisabled()
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Text("Use 0 for a zero-spend goal.")
                        .font(.footnote).foregroundStyle(Palette.muted)

                    if currentLimit != nil {
                        Button(role: .destructive) {
                            removeBudget()
                        } label: {
                            Label("Remove this budget", systemImage: "trash")
                                .font(.subheadline.weight(.semibold))
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            .pennyBackground()
            .navigationTitle("\(category.label) budget")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save", action: save).fontWeight(.bold) }
            }
            .onAppear {
                text = currentLimit.map { Money.inputText($0) } ?? ""
                focused = true
            }
        }
        .lockGuard()
    }

    private func suggestion(_ title: String, _ cents: Int) -> some View {
        Button {
            Haptics.selection()
            text = Money.inputText(cents)
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.caption).foregroundStyle(Palette.muted)
                Text(Money.format(cents, currency: currency)).font(Typography.money(15, weight: .bold))
                    .foregroundStyle(Palette.ink)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Palette.line))
        }
        .buttonStyle(PressableStyle())
    }

    private func upsert(_ cents: Int) {
        let key = DateText.monthKey(month)
        if let existing = budgets.first(where: { $0.monthKey == key && $0.category == category }) {
            existing.limitCents = cents
        } else {
            context.insert(BudgetLimit(monthKey: key, category: category, limitCents: cents))
        }
        try? context.save()
    }

    private func save() {
        guard let cents = Money.parse(text, allowZero: true) else {
            showError = true
            Haptics.warning()
            return
        }
        upsert(cents)
        Haptics.success()
        state.show("\(category.label) budget saved.")
        dismiss()
    }

    private func removeBudget() {
        upsert(-1)
        state.show("\(category.label) budget removed from \(DateText.monthName(month)) on.", symbol: "minus.circle.fill")
        dismiss()
    }
}
