import Charts
import SwiftData
import SwiftUI

struct InsightsView: View {
    @Environment(AppState.self) private var state
    @Query private var entries: [LedgerEntry]
    @Query private var budgets: [BudgetLimit]
    @AppStorage("currency") private var currencyRaw = CurrencyCode.usd.rawValue

    private var currency: CurrencyCode { CurrencyCode(rawValue: currencyRaw) ?? .usd }

    var body: some View {
        let calendar = Calendar.current
        let current = MonthSummary(month: state.selectedMonth, allEntries: entries, budgets: budgets)
        let previous = MonthSummary(month: calendar.month(offset: -1, from: state.selectedMonth),
                                    allEntries: entries, budgets: budgets)
        let history = (0..<6).reversed().map { back in
            MonthSummary(month: calendar.month(offset: -back, from: state.selectedMonth),
                         allEntries: entries, budgets: budgets)
        }

        ScrollView {
            VStack(spacing: 16) {
                MonthSwitcher()
                ComparisonCard(current: current, previous: previous, currency: currency)
                CategoryDonutCard(summary: current, currency: currency)
                TrendCard(history: history, currency: currency)
                PaceCard(summary: current, currency: currency)
                if let top = current.rankedCategories.first {
                    let share = Int((100 * Double(current.spent(top)) / Double(max(1, current.expenses))).rounded())
                    HStack(alignment: .top, spacing: 14) {
                        Image(systemName: top.symbol).font(.title2).foregroundStyle(Palette.blue)
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Your largest category: \(top.label)").font(.headline).foregroundStyle(Palette.ink)
                            Text("\(Money.format(current.spent(top), currency: currency)) makes up \(share)% of this month’s expenses. Category budgets help you compare this with your own plan.")
                                .font(.subheadline).foregroundStyle(Palette.ink)
                        }
                    }
                    .card(fill: Palette.paleBlue, bordered: false)
                    .accessibilityElement(children: .combine)
                }
            }
            .padding()
        }
        .background(Palette.background)
        .navigationTitle("Insights")
    }
}

// MARK: - Month comparison

struct ComparisonCard: View {
    let current: MonthSummary
    let previous: MonthSummary
    let currency: CurrencyCode

    var body: some View {
        let delta = current.expenses - previous.expenses
        let elapsed = current.elapsedDays(today: Date())
        let average = elapsed == 0 ? 0 : current.expenses / elapsed
        let headline: String = {
            if current.expenses == 0 { return "A fresh month of possibilities." }
            if previous.expenses == 0 { return "Your spending story starts here." }
            return delta <= 0 ? "A little more breathing room." : "A clearer view of your spending."
        }()
        let detail: String = {
            guard previous.expenses > 0 else {
                return "There are no expenses in the previous month to compare with yet."
            }
            let percent = Int((Double(abs(delta)) * 100 / Double(previous.expenses)).rounded())
            return "You spent \(Money.format(abs(delta), currency: currency)) (\(percent)%) \(delta <= 0 ? "less" : "more") than in \(DateText.monthName(previous.month)). This compares the selected month so far with the previous full month."
        }()

        VStack(alignment: .leading, spacing: 12) {
            Text("THE BIGGER PICTURE")
                .font(.caption2.weight(.bold)).tracking(1.4)
                .foregroundStyle(Palette.blue)
            Text(headline).font(.title2.weight(.heavy)).foregroundStyle(Palette.ink)
            Text(detail).font(.subheadline).foregroundStyle(Palette.muted)
            HStack(spacing: 24) {
                number("Daily average", Money.format(average, currency: currency))
                number("Expense entries", "\(current.expenseEntries.count)")
                number("Net flow", Money.format(current.net, currency: currency))
            }
            .padding(.top, 4)
        }
        .card()
    }

    private func number(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundStyle(Palette.muted)
            Text(value).font(.headline.monospacedDigit()).foregroundStyle(Palette.ink)
                .minimumScaleFactor(0.6).lineLimit(1)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Category donut

struct CategoryDonutCard: View {
    let summary: MonthSummary
    let currency: CurrencyCode

    var body: some View {
        let categories = summary.rankedCategories
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle(title: "Spending mix", subtitle: "Share of this month’s expenses by category")
            if categories.isEmpty {
                Text("No expenses this month yet.").font(.subheadline).foregroundStyle(Palette.muted)
            } else {
                Chart(categories) { category in
                    SectorMark(angle: .value("Spent", Double(summary.spent(category)) / 100),
                               innerRadius: .ratio(0.62),
                               angularInset: 1.5)
                        .cornerRadius(4)
                        .foregroundStyle(category.color)
                        .accessibilityLabel(Text(category.label))
                        .accessibilityValue(Text(Money.format(summary.spent(category), currency: currency)))
                }
                .chartBackground { _ in
                    VStack(spacing: 2) {
                        Text("Total").font(.caption).foregroundStyle(Palette.muted)
                        Text(Money.format(summary.expenses, currency: currency))
                            .font(.headline.monospacedDigit()).foregroundStyle(Palette.ink)
                    }
                }
                .frame(height: 220)

                VStack(spacing: 8) {
                    ForEach(categories) { category in
                        HStack(spacing: 8) {
                            Circle().fill(category.color).frame(width: 10, height: 10)
                            Text(category.label).font(.subheadline).foregroundStyle(Palette.ink)
                            Spacer()
                            Text(Money.format(summary.spent(category), currency: currency))
                                .font(.subheadline.weight(.semibold).monospacedDigit())
                                .foregroundStyle(Palette.ink)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
            }
        }
        .card()
    }
}

// MARK: - Six-month trend

struct TrendCard: View {
    let history: [MonthSummary]
    let currency: CurrencyCode

    private struct Point: Identifiable {
        let month: Date
        let series: String
        let cents: Int
        var id: String { "\(series)-\(month.timeIntervalSince1970)" }
    }

    var body: some View {
        let points = history.flatMap { summary in
            [Point(month: summary.month, series: "Expenses", cents: summary.expenses),
             Point(month: summary.month, series: "Income", cents: summary.income)]
        }
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle(title: "Six-month trend", subtitle: "Money in and out, month by month")
            Chart(points) { point in
                BarMark(x: .value("Month", point.month, unit: .month),
                        y: .value("Amount", Double(point.cents) / 100))
                    .foregroundStyle(by: .value("Type", point.series))
                    .position(by: .value("Type", point.series))
                    .cornerRadius(4)
            }
            .chartForegroundStyleScale(["Expenses": Palette.blue, "Income": Palette.green])
            .chartXAxis {
                AxisMarks(values: .stride(by: .month)) { _ in
                    AxisValueLabel(format: .dateTime.month(.abbreviated), centered: true)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let amount = value.as(Double.self) { Text(compact(amount)) }
                    }
                }
            }
            .chartLegend(position: .top, alignment: .leading)
            .frame(height: 220)
        }
        .card()
    }

    private func compact(_ amount: Double) -> String {
        if amount >= 1_000 { return "\(currency.symbol)\(Int(amount / 1_000))k" }
        return "\(currency.symbol)\(Int(amount))"
    }
}

// MARK: - Budget pace

struct PaceCard: View {
    let summary: MonthSummary
    let currency: CurrencyCode

    private struct Point: Identifiable {
        let day: Int
        let series: String
        let amount: Double
        var id: String { "\(series)-\(day)" }
    }

    private var lastDay: Int { summary.elapsedDays(today: Date()) }

    private var points: [Point] {
        let calendar = Calendar.current
        let days = summary.daysInMonth
        var running = 0
        var result: [Point] = []
        for day in 1...days {
            let plan = Double(summary.budget) / 100 * Double(day) / Double(days)
            result.append(Point(day: day, series: "Plan pace", amount: plan))
            if day <= lastDay, let date = calendar.date(byAdding: .day, value: day - 1, to: summary.month) {
                running += summary.spent(on: date)
                result.append(Point(day: day, series: "Spent", amount: Double(running) / 100))
            }
        }
        return result
    }

    var body: some View {
        let days = summary.daysInMonth
        let onTrack = summary.expenses <= Int(Double(summary.budget) * Double(lastDay) / Double(max(days, 1)))
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle(title: "Budget pace",
                         subtitle: lastDay == 0 ? "This month hasn’t started yet."
                         : (onTrack ? "You’re at or under your plan’s pace." : "You’re spending faster than your plan."))
            Chart(points) { point in
                LineMark(x: .value("Day", point.day), y: .value("Amount", point.amount))
                    .foregroundStyle(by: .value("Series", point.series))
                    .lineStyle(StrokeStyle(lineWidth: point.series == "Spent" ? 3 : 2,
                                           dash: point.series == "Spent" ? [] : [5, 4]))
                    .interpolationMethod(.monotone)
            }
            .chartForegroundStyleScale(["Spent": Palette.blue, "Plan pace": Palette.muted])
            .chartXScale(domain: 1...days)
            .chartXAxisLabel("Day of month")
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let amount = value.as(Double.self) { Text("\(currency.symbol)\(Int(amount))") }
                    }
                }
            }
            .chartLegend(position: .top, alignment: .leading)
            .frame(height: 200)
        }
        .card()
    }
}
