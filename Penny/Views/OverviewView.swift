import Charts
import SwiftData
import SwiftUI

struct OverviewView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var state
    @Query(sort: \LedgerEntry.date, order: .reverse) private var entries: [LedgerEntry]
    @Query private var budgets: [BudgetLimit]
    @AppStorage("currency") private var currencyRaw = CurrencyCode.usd.rawValue
    @Binding var selectedTab: Int
    @State private var editor: EditorTarget?
    @State private var confirmRemoveSamples = false

    private var currency: CurrencyCode { CurrencyCode(rawValue: currencyRaw) ?? .usd }

    var body: some View {
        let summary = MonthSummary(month: state.selectedMonth, allEntries: entries, budgets: budgets)
        ScrollView {
            VStack(spacing: 16) {
                MonthSwitcher()
                if entries.contains(where: { $0.isSample }) {
                    SampleBanner { confirmRemoveSamples = true }
                }
                BudgetHero(summary: summary, currency: currency) { selectedTab = 2 }
                HStack(spacing: 12) {
                    StatTile(label: "Money in", value: Money.format(summary.income, currency: currency),
                             symbol: "arrow.down.left", tint: Palette.green)
                    StatTile(label: "Money out", value: Money.format(summary.expenses, currency: currency),
                             symbol: "arrow.up.right")
                    StatTile(label: "Net flow", value: Money.format(summary.net, currency: currency),
                             symbol: "arrow.left.arrow.right", tint: Palette.muted)
                }
                WeekChartCard(summary: summary, currency: currency)
                CategoryBreakdownCard(summary: summary, currency: currency, limit: 5)
                recentActivity(summary)
            }
            .padding()
        }
        .background(Palette.background)
        .navigationTitle("Penny")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { editor = .new } label: { Label("Add transaction", systemImage: "plus.circle.fill") }
            }
        }
        .sheet(item: $editor) { target in EntryFormView(target: target) }
        .confirmationDialog("Remove all sample data?", isPresented: $confirmRemoveSamples, titleVisibility: .visible) {
            Button("Remove sample data", role: .destructive) { removeSamples() }
        } message: {
            Text("Transactions you added yourself are kept.")
        }
    }

    private func recentActivity(_ summary: MonthSummary) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                SectionTitle(title: "Recent activity", subtitle: "The latest in your money story")
                Button("View all") { selectedTab = 1 }.font(.subheadline.weight(.bold))
            }
            if summary.entries.isEmpty {
                VStack(spacing: 12) {
                    Text("Your first step starts here").font(.headline).foregroundStyle(Palette.ink)
                    Text("Add an expense or income. Your overview updates automatically.")
                        .font(.subheadline).foregroundStyle(Palette.muted).multilineTextAlignment(.center)
                    Button { editor = .new } label: { Label("Add a transaction", systemImage: "plus") }
                        .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                ForEach(summary.entries.prefix(5)) { entry in
                    Button { editor = .edit(entry) } label: { EntryRow(entry: entry, currency: currency) }
                        .buttonStyle(.plain)
                    if entry.id != summary.entries.prefix(5).last?.id { Divider() }
                }
            }
        }
        .card()
    }

    private func removeSamples() {
        for entry in entries where entry.isSample { context.delete(entry) }
        try? context.save()
        state.show("Sample data removed. Your fresh start is ready.")
    }
}

// MARK: - Budget hero

struct BudgetHero: View {
    let summary: MonthSummary
    let currency: CurrencyCode
    let onManage: () -> Void

    var body: some View {
        let over = summary.remaining < 0
        let ratio = summary.budget == 0 ? 0 : Double(summary.expenses) / Double(summary.budget)
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("YOUR MONTHLY PLAN")
                    .font(.caption2.weight(.bold)).tracking(1.4)
                    .foregroundStyle(Palette.heroText)
                Spacer()
                Label(over ? "Over budget" : (summary.budget == 0 ? "No budget set" : "Within your plan"),
                      systemImage: over ? "exclamationmark.circle" : "checkmark.circle")
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Palette.lime, in: Capsule())
                    .foregroundStyle(Palette.navy)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(over ? "Over your plan by" : "Left to spend")
                    .font(.subheadline).foregroundStyle(Palette.heroText)
                Text(Money.format(abs(summary.remaining), currency: currency))
                    .font(.system(size: 44, weight: .heavy, design: .rounded).monospacedDigit())
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
            }
            .accessibilityElement(children: .combine)
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Spent so far").font(.footnote).foregroundStyle(Palette.heroText)
                    Spacer()
                    Text(summary.budget == 0 ? "No limit" : "\(Int((ratio * 100).rounded()))% of plan")
                        .font(.footnote.weight(.bold)).foregroundStyle(Palette.lime)
                }
                ProgressBar(value: ratio, tint: Palette.lime, track: Palette.heroTrack, height: 9)
                HStack(spacing: 24) {
                    heroStat("Spent", Money.format(summary.expenses, currency: currency))
                    heroStat("Planned", Money.format(summary.budget, currency: currency))
                    Spacer()
                    Button(action: onManage) {
                        Label("Manage", systemImage: "slider.horizontal.3").font(.footnote.weight(.bold))
                    }
                    .foregroundStyle(Palette.lime)
                }
                .padding(.top, 4)
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.navy, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func heroStat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption).foregroundStyle(Palette.heroText)
            Text(value).font(.subheadline.weight(.bold).monospacedDigit()).foregroundStyle(.white)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Last 7 days chart

struct WeekChartCard: View {
    let summary: MonthSummary
    let currency: CurrencyCode
    @State private var selectedDay: Date?

    private struct DayValue: Identifiable {
        let day: Date
        let cents: Int
        var id: Date { day }
    }

    private var days: [DayValue] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let end: Date
        if calendar.isDate(summary.month, equalTo: today, toGranularity: .month) {
            end = today
        } else {
            let nextMonth = calendar.month(offset: 1, from: summary.month)
            end = calendar.date(byAdding: .day, value: -1, to: nextMonth) ?? summary.month
        }
        return (0..<7).reversed().compactMap { back in
            guard let day = calendar.date(byAdding: .day, value: -back, to: end),
                  calendar.isDate(day, equalTo: summary.month, toGranularity: .month) else { return nil }
            return DayValue(day: day, cents: summary.spent(on: day))
        }
    }

    var body: some View {
        let values = days
        let total = values.reduce(0) { $0 + $1.cents }
        let picked = selectedDay.flatMap { selection in
            values.first { Calendar.current.isDate($0.day, inSameDayAs: selection) }
        }
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "Spending rhythm",
                         subtitle: "Daily expenses · last \(values.count) days of \(DateText.monthName(summary.month))")
            Text(picked.map { "\(DateText.short($0.day)): \(Money.format($0.cents, currency: currency))" }
                 ?? Money.format(total, currency: currency))
                .font(.title2.weight(.heavy).monospacedDigit())
                .foregroundStyle(Palette.ink)
                .contentTransition(.numericText())
            Chart(values) { value in
                BarMark(x: .value("Day", value.day, unit: .day),
                        y: .value("Spent", Double(value.cents) / 100))
                    .foregroundStyle(picked?.day == value.day ? Palette.blue : Palette.blue.opacity(0.55))
                    .cornerRadius(6)
            }
            .chartXSelection(value: $selectedDay)
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { _ in
                    AxisValueLabel(format: .dateTime.weekday(.narrow), centered: true)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let amount = value.as(Double.self) { Text("\(currency.symbol)\(Int(amount))") }
                    }
                }
            }
            .frame(height: 180)
            Text("Touch and hold a bar to see that day.")
                .font(.caption).foregroundStyle(Palette.muted)
        }
        .card()
    }
}

// MARK: - Category breakdown

struct CategoryBreakdownCard: View {
    let summary: MonthSummary
    let currency: CurrencyCode
    var limit = 5

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle(title: "Where it went", subtitle: "Expenses by category")
            let categories = Array(summary.rankedCategories.prefix(limit))
            if categories.isEmpty {
                Text("Add an expense to see your category breakdown.")
                    .font(.subheadline).foregroundStyle(Palette.muted)
                    .padding(.vertical, 12)
            }
            ForEach(categories) { category in
                let cents = summary.spent(category)
                let share = summary.expenses == 0 ? 0 : Double(cents) / Double(summary.expenses)
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 10) {
                        CategoryBadge(category: category, size: 34)
                        Text(category.label).font(.subheadline.weight(.semibold)).foregroundStyle(Palette.ink)
                        Spacer()
                        Text(Money.format(cents, currency: currency))
                            .font(.subheadline.weight(.bold).monospacedDigit()).foregroundStyle(Palette.ink)
                    }
                    ProgressBar(value: share, tint: category.color, track: Palette.background, height: 6)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(category.label), \(Money.format(cents, currency: currency)), \(Int((share * 100).rounded())) percent of spending")
            }
        }
        .card()
    }
}
