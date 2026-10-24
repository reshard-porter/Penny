import Charts
import SwiftData
import SwiftUI

struct InsightsView: View {
    @Environment(AppState.self) private var state
    @Query(sort: \LedgerEntry.date, order: .reverse) private var entries: [LedgerEntry]
    @Query private var budgets: [BudgetLimit]
    @Query(filter: #Predicate<RecurringRule> { $0.isActive }) private var rules: [RecurringRule]
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
        let windowEnd = current.isCurrentMonth() ? Date() : calendar.endOfMonth(for: current.month)

        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 16) {
                    MonthSwitcher()
                    ScoreHero(current: current, previous: previous, currency: currency)
                    CategoryDonutCard(summary: current, currency: currency)
                    PaceCard(current: current, previous: previous, currency: currency)
                        .id("more")
                    TrendCard(history: history, currency: currency)
                    WeekdayCard(values: InsightsMath.weekdayAverages(entries, endingAt: windowEnd), currency: currency)
                    TopPlacesCard(merchants: InsightsMath.topMerchants(current.expenseEntries), currency: currency)
                    if !current.expenseEntries.isEmpty {
                        BiggestCard(entries: Array(current.expenseEntries.sorted { $0.amountCents > $1.amountCents }.prefix(3)),
                                    currency: currency)
                    }
                    if !current.rankedIncomeCategories.isEmpty {
                        IncomeCard(summary: current, currency: currency)
                    }
                    CommitmentsCard(rules: rules, income: max(current.income, previous.income), currency: currency)
                        .id("end")
                }
                .padding(.horizontal)
                .padding(.bottom, 40)
            }
            .screenshotScroll(proxy)
        }
        .pennyBackground()
        .navigationTitle("Insights")
    }
}

// MARK: - Score hero

struct ScoreHero: View {
    let current: MonthSummary
    let previous: MonthSummary
    let currency: CurrencyCode

    var body: some View {
        let rate = current.savingsRate
        let change = InsightsMath.change(from: previous.expenses, to: current.expenses)
        let headline: String = {
            guard current.expenses > 0 || current.income > 0 else { return "A fresh month awaits." }
            guard let change else { return "Your money story starts here." }
            if change <= -5 { return "Spending is down. Nice work." }
            if change >= 5 { return "Spending is up this month." }
            return "Steady as she goes."
        }()

        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center, spacing: 18) {
                ZStack {
                    RingProgress(value: max(0, rate ?? 0), lineWidth: 12, track: Palette.heroTrack)
                    VStack(spacing: 0) {
                        Text(rate.map { "\(Int(($0 * 100).rounded()))%" } ?? "—")
                            .font(Typography.money(24, weight: .heavy))
                            .foregroundStyle(.white)
                            .minimumScaleFactor(0.6)
                        Text("saved").font(.caption2.weight(.semibold)).foregroundStyle(Palette.heroText)
                    }
                    .padding(8)
                }
                .frame(width: 100, height: 100)

                VStack(alignment: .leading, spacing: 6) {
                    Eyebrow(text: "\(DateText.monthName(current.month)) at a glance")
                    Text(headline)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                    if let change {
                        Label("\(abs(change))% \(change <= 0 ? "less" : "more") than \(DateText.monthName(previous.month))",
                              systemImage: change <= 0 ? "arrow.down.right" : "arrow.up.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(change <= 0 ? Palette.lime : Color(hex: 0xFFB4A8))
                    }
                }
            }
            HStack(spacing: 0) {
                stat("Spent", Money.short(current.expenses, currency: currency))
                Spacer()
                stat("Earned", Money.short(current.income, currency: currency))
                Spacer()
                stat("Daily avg", Money.short(current.expenses / max(current.elapsedDays(today: Date()), 1), currency: currency))
            }
        }
        .heroCard()
        .accessibilityElement(children: .combine)
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label).font(.caption).foregroundStyle(Palette.heroFaint)
            Text(value).font(Typography.money(17, weight: .bold)).foregroundStyle(.white)
                .lineLimit(1).minimumScaleFactor(0.7)
        }
    }
}

// MARK: - Category donut

struct CategoryDonutCard: View {
    let summary: MonthSummary
    let currency: CurrencyCode
    @State private var selectedAngle: Double?

    /// The six largest categories plus one slice for everything else, so tiny slices don't splinter the ring.
    private struct Slice: Identifiable, Equatable {
        let id: String
        let label: String
        let symbol: String
        let color: Color
        let cents: Int
    }

    private var slices: [Slice] {
        let ranked = summary.rankedCategories
        var result = ranked.prefix(6).map { category in
            Slice(id: category.rawValue, label: category.label, symbol: category.symbol,
                  color: category.color, cents: summary.spent(category))
        }
        let rest = ranked.dropFirst(6).reduce(0) { $0 + summary.spent($1) }
        if rest > 0 {
            let count = ranked.count - 6
            result.append(Slice(id: "rest", label: "\(count) more", symbol: "ellipsis.circle.fill",
                                color: Palette.faint, cents: rest))
        }
        return result
    }

    private func slice(at angle: Double?, in slices: [Slice]) -> Slice? {
        guard let angle else { return nil }
        var running = 0.0
        for slice in slices {
            running += Double(slice.cents) / 100
            if angle <= running { return slice }
        }
        return nil
    }

    var body: some View {
        let slices = self.slices
        let selected = slice(at: selectedAngle, in: slices)
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Spending mix", subtitle: "Touch the ring to explore")
            if slices.isEmpty {
                Text("No expenses this month yet.").font(.subheadline).foregroundStyle(Palette.muted)
            } else {
                Chart(slices) { slice in
                    SectorMark(angle: .value("Spent", Double(slice.cents) / 100),
                               innerRadius: .ratio(0.64),
                               outerRadius: .ratio(selected == slice ? 1 : 0.93),
                               angularInset: 1.5)
                        .cornerRadius(4)
                        .foregroundStyle(Gradients.tint(slice.color))
                        .opacity(selected == nil || selected == slice ? 1 : 0.35)
                        .accessibilityLabel(Text(slice.label))
                        .accessibilityValue(Text(Money.format(slice.cents, currency: currency)))
                }
                .chartAngleSelection(value: $selectedAngle)
                .chartBackground { _ in
                    VStack(spacing: 2) {
                        if let selected {
                            Image(systemName: selected.symbol).foregroundStyle(selected.color)
                            Text(selected.label).font(.caption.weight(.semibold)).foregroundStyle(Palette.muted)
                            Text(Money.short(selected.cents, currency: currency))
                                .font(Typography.money(20, weight: .heavy)).foregroundStyle(Palette.ink)
                            Text("\(share(selected.cents))% of spending").font(.caption2).foregroundStyle(Palette.muted)
                        } else {
                            Text("Total").font(.caption.weight(.semibold)).foregroundStyle(Palette.muted)
                            Text(Money.short(summary.expenses, currency: currency))
                                .font(Typography.money(22, weight: .heavy)).foregroundStyle(Palette.ink)
                            Text("\(summary.rankedCategories.count) categories").font(.caption2).foregroundStyle(Palette.muted)
                        }
                    }
                }
                .frame(height: 240)
                .animation(.snappy, value: selected)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 10) {
                    ForEach(slices) { slice in
                        HStack(spacing: 8) {
                            Circle().fill(slice.color).frame(width: 9, height: 9)
                            Text(slice.label).font(.caption).foregroundStyle(Palette.ink).lineLimit(1)
                            Spacer(minLength: 2)
                            Text("\(share(slice.cents))%").font(.caption.weight(.semibold).monospacedDigit())
                                .foregroundStyle(Palette.muted)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
            }
        }
        .card()
    }

    private func share(_ cents: Int) -> Int {
        guard summary.expenses > 0 else { return 0 }
        return Int((Double(cents) * 100 / Double(summary.expenses)).rounded())
    }
}

// MARK: - Pace

struct PaceCard: View {
    let current: MonthSummary
    let previous: MonthSummary
    let currency: CurrencyCode

    private struct Point: Identifiable {
        let day: Int
        let series: String
        let amount: Double
        var id: String { "\(series)-\(day)" }
    }

    var body: some View {
        let elapsed = current.elapsedDays(today: Date())
        let days = current.daysInMonth
        let thisMonth = current.cumulativeSpending.prefix(elapsed).enumerated().map {
            Point(day: $0.offset + 1, series: "This month", amount: Double($0.element) / 100)
        }
        let lastMonth = previous.cumulativeSpending.enumerated().map {
            Point(day: $0.offset + 1, series: "Last month", amount: Double($0.element) / 100)
        }.filter { $0.day <= days }
        let plan: [Point] = current.hasBudget
            ? [Point(day: 1, series: "Plan", amount: 0),
               Point(day: days, series: "Plan", amount: Double(current.budget) / 100)]
            : []
        let lastAtSameDay = previous.cumulativeSpending.indices.contains(elapsed - 1)
            ? previous.cumulativeSpending[elapsed - 1] : previous.expenses
        let diff = current.expenses - lastAtSameDay

        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Spending pace",
                          subtitle: elapsed == 0 ? "This month hasn’t started yet."
                          : (previous.expenses == 0 ? "Running total by day"
                             : "\(Money.short(abs(diff), currency: currency)) \(diff <= 0 ? "less" : "more") than this point last month"))
            Chart {
                ForEach(thisMonth) { point in
                    AreaMark(x: .value("Day", point.day), y: .value("Amount", point.amount))
                        .foregroundStyle(LinearGradient(colors: [Palette.blue.opacity(0.35), Palette.blue.opacity(0.02)],
                                                        startPoint: .top, endPoint: .bottom))
                        .interpolationMethod(.monotone)
                    LineMark(x: .value("Day", point.day), y: .value("Amount", point.amount),
                             series: .value("Series", point.series))
                        .foregroundStyle(Palette.blue)
                        .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                        .interpolationMethod(.monotone)
                }
                ForEach(lastMonth) { point in
                    LineMark(x: .value("Day", point.day), y: .value("Amount", point.amount),
                             series: .value("Series", point.series))
                        .foregroundStyle(Palette.faint)
                        .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
                        .interpolationMethod(.monotone)
                }
                ForEach(plan) { point in
                    LineMark(x: .value("Day", point.day), y: .value("Amount", point.amount),
                             series: .value("Series", point.series))
                        .foregroundStyle(Palette.green)
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                }
                if let last = thisMonth.last {
                    PointMark(x: .value("Day", last.day), y: .value("Amount", last.amount))
                        .foregroundStyle(Palette.blue)
                        .symbolSize(80)
                }
            }
            .chartXScale(domain: 1...max(days, 2))
            .chartXAxis {
                AxisMarks(values: [1, 8, 15, 22, days]) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 3]))
                    AxisValueLabel { if let day = value.as(Int.self) { Text("\(day)") } }
                }
            }
            .chartYAxis {
                AxisMarks(position: .trailing, values: .automatic(desiredCount: 4)) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 3]))
                    AxisValueLabel {
                        if let amount = value.as(Double.self) { Text(Money.compact(Int(amount * 100), currency: currency)) }
                    }
                }
            }
            .frame(height: 210)

            HStack(spacing: 16) {
                legend("This month", Palette.blue, dashed: false)
                legend("Last month", Palette.faint, dashed: false)
                if current.hasBudget { legend("Plan", Palette.green, dashed: true) }
            }
        }
        .card()
    }

    private func legend(_ title: String, _ color: Color, dashed: Bool) -> some View {
        HStack(spacing: 6) {
            Capsule()
                .stroke(color, style: StrokeStyle(lineWidth: 3, dash: dashed ? [3, 2] : []))
                .frame(width: 16, height: 3)
            Text(title).font(.caption).foregroundStyle(Palette.muted)
        }
    }
}

// MARK: - Six-month trend

struct TrendCard: View {
    let history: [MonthSummary]
    let currency: CurrencyCode
    @State private var selectedMonth: Date?

    private struct Point: Identifiable {
        let month: Date
        let series: String
        let cents: Int
        var id: String { "\(series)-\(month.timeIntervalSince1970)" }
    }

    var body: some View {
        let points = history.flatMap { summary in
            [Point(month: summary.month, series: "Income", cents: summary.income),
             Point(month: summary.month, series: "Expenses", cents: summary.expenses)]
        }
        let picked = selectedMonth.flatMap { date in
            history.first { Calendar.current.isDate($0.month, equalTo: date, toGranularity: .month) }
        }
        let totalNet = history.reduce(0) { $0 + $1.net }

        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                SectionHeader(title: "Six-month trend",
                              subtitle: picked.map { DateText.month($0.month) } ?? "Money in and out")
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(picked == nil ? "6-mo net" : "Net").font(.caption).foregroundStyle(Palette.muted)
                    let net = picked?.net ?? totalNet
                    Text((net >= 0 ? "+" : "") + Money.short(net, currency: currency))
                        .font(Typography.money(16, weight: .bold))
                        .foregroundStyle(net >= 0 ? Palette.green : Palette.red)
                }
            }
            Chart(points) { point in
                BarMark(x: .value("Month", point.month, unit: .month),
                        y: .value("Amount", Double(point.cents) / 100))
                    .foregroundStyle(by: .value("Type", point.series))
                    .position(by: .value("Type", point.series))
                    .cornerRadius(5)
                    .opacity(picked == nil || Calendar.current.isDate(point.month, equalTo: picked?.month ?? .distantPast,
                                                                       toGranularity: .month) ? 1 : 0.35)
            }
            .chartForegroundStyleScale(["Income": Palette.green, "Expenses": Palette.blue])
            .chartXSelection(value: $selectedMonth)
            .chartXAxis {
                AxisMarks(values: .stride(by: .month)) { _ in
                    AxisValueLabel(format: .dateTime.month(.abbreviated), centered: true)
                }
            }
            .chartYAxis {
                AxisMarks(position: .trailing, values: .automatic(desiredCount: 4)) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 3]))
                    AxisValueLabel {
                        if let amount = value.as(Double.self) { Text(Money.compact(Int(amount * 100), currency: currency)) }
                    }
                }
            }
            .chartLegend(position: .bottom, alignment: .leading)
            .frame(height: 220)
        }
        .card()
    }
}

// MARK: - Weekday rhythm

struct WeekdayCard: View {
    let values: [InsightsMath.WeekdayValue]
    let currency: CurrencyCode

    var body: some View {
        let peak = values.max { $0.averageCents < $1.averageCents }
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Weekly rhythm",
                          subtitle: peak.map { $0.averageCents > 0
                              ? "\(Calendar.current.weekdaySymbols[$0.weekday - 1])s are your biggest spending days"
                              : "Average spending by weekday" } ?? "Average spending by weekday")
            Chart(values) { value in
                BarMark(x: .value("Day", value.label), y: .value("Average", Double(value.averageCents) / 100),
                        width: .ratio(0.6))
                    .foregroundStyle(value.weekday == peak?.weekday && (peak?.averageCents ?? 0) > 0
                                     ? AnyShapeStyle(Gradients.tint(Color(hex: 0xEA580C)))
                                     : AnyShapeStyle(Palette.blue.opacity(0.3)))
                    .cornerRadius(6)
                    .annotation(position: .top) {
                        if value.weekday == peak?.weekday && value.averageCents > 0 {
                            Text(Money.compact(value.averageCents, currency: currency))
                                .font(.caption2.weight(.bold)).foregroundStyle(Color(hex: 0xEA580C))
                        }
                    }
            }
            .chartYAxis(.hidden)
            .frame(height: 150)
            Text("Average per day over the last 13 weeks.")
                .font(.caption).foregroundStyle(Palette.muted)
        }
        .card()
    }
}

// MARK: - Top places

struct TopPlacesCard: View {
    let merchants: [InsightsMath.Merchant]
    let currency: CurrencyCode

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Where you spend most", subtitle: "By description this month")
            if merchants.isEmpty {
                Text("Nothing to rank yet.").font(.subheadline).foregroundStyle(Palette.muted)
            }
            let top = merchants.first?.cents ?? 1
            ForEach(Array(merchants.enumerated()), id: \.element.id) { index, merchant in
                HStack(spacing: 12) {
                    Text("\(index + 1)")
                        .font(Typography.money(14, weight: .heavy))
                        .foregroundStyle(index == 0 ? Palette.navy : Palette.muted)
                        .frame(width: 28, height: 28)
                        .background(index == 0 ? AnyShapeStyle(Gradients.lime) : AnyShapeStyle(Palette.surfaceRaised),
                                    in: Circle())
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text(merchant.title).font(.subheadline.weight(.semibold)).foregroundStyle(Palette.ink)
                                .lineLimit(1)
                            if merchant.count > 1 {
                                Text("×\(merchant.count)").font(.caption.weight(.semibold)).foregroundStyle(Palette.muted)
                            }
                            Spacer()
                            Text(Money.format(merchant.cents, currency: currency))
                                .font(Typography.money(15, weight: .bold)).foregroundStyle(Palette.ink)
                        }
                        ProgressBar(value: Double(merchant.cents) / Double(max(top, 1)),
                                    tint: AnyShapeStyle(Gradients.tint(merchant.category.color)),
                                    track: Palette.surfaceRaised, height: 5)
                    }
                }
                .accessibilityElement(children: .combine)
            }
        }
        .card()
    }
}

// MARK: - Biggest expenses

struct BiggestCard: View {
    @Environment(AppState.self) private var state
    let entries: [LedgerEntry]
    let currency: CurrencyCode

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Biggest expenses", subtitle: nil)
            ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                if index > 0 { Divider().padding(.leading, 58) }
                Button { state.editor = .edit(entry) } label: { EntryRow(entry: entry, currency: currency) }
                    .buttonStyle(PressableStyle(scale: 0.98))
            }
        }
        .card()
    }
}

// MARK: - Income sources

struct IncomeCard: View {
    let summary: MonthSummary
    let currency: CurrencyCode

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Income sources", subtitle: "\(Money.short(summary.income, currency: currency)) received")
            GeometryReader { proxy in
                HStack(spacing: 3) {
                    ForEach(summary.rankedIncomeCategories) { category in
                        let share = Double(summary.earned(category)) / Double(max(summary.income, 1))
                        Rectangle()
                            .fill(Gradients.tint(category.color))
                            .frame(width: max(4, (proxy.size.width - 3 * CGFloat(summary.rankedIncomeCategories.count - 1)) * share))
                    }
                }
                .clipShape(Capsule())
            }
            .frame(height: 14)
            ForEach(summary.rankedIncomeCategories) { category in
                HStack(spacing: 10) {
                    CategoryBadge(category: category, size: 32)
                    Text(category.label).font(.subheadline.weight(.semibold)).foregroundStyle(Palette.ink)
                    Spacer()
                    Text(Money.format(summary.earned(category), currency: currency))
                        .font(Typography.money(15, weight: .bold)).foregroundStyle(Palette.green)
                }
                .accessibilityElement(children: .combine)
            }
        }
        .card()
    }
}

// MARK: - Recurring commitments

struct CommitmentsCard: View {
    let rules: [RecurringRule]
    let income: Int
    let currency: CurrencyCode

    var body: some View {
        let expenseRules = rules.filter { $0.kind == .expense }.sorted { $0.monthlyCents > $1.monthlyCents }
        let monthly = expenseRules.reduce(0) { $0 + $1.monthlyCents }
        let share = income > 0 ? Double(monthly) / Double(income) : nil

        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Fixed commitments", subtitle: "Recurring expenses, per month")
            HStack(alignment: .firstTextBaseline) {
                Text(Money.short(monthly, currency: currency))
                    .font(Typography.money(30, weight: .heavy)).foregroundStyle(Palette.ink)
                    .lineLimit(1).minimumScaleFactor(0.6)
                Text("/ month").font(.subheadline).foregroundStyle(Palette.muted)
                    .fixedSize()
                Spacer()
                if let share {
                    Text("\(Int((share * 100).rounded()))% of income")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(share > 0.6 ? Palette.orange : Palette.green)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background((share > 0.6 ? Palette.orange : Palette.green).opacity(0.12), in: Capsule())
                }
            }
            if expenseRules.isEmpty {
                Text("Add rent, subscriptions and bills as recurring to see them here.")
                    .font(.subheadline).foregroundStyle(Palette.muted)
            }
            ForEach(expenseRules.prefix(5)) { rule in
                HStack(spacing: 10) {
                    CategoryBadge(category: rule.category, size: 30)
                    Text(rule.title).font(.subheadline).foregroundStyle(Palette.ink).lineLimit(1)
                    Text(rule.frequency.shortLabel).font(.caption).foregroundStyle(Palette.muted)
                    Spacer()
                    Text(Money.short(rule.monthlyCents, currency: currency))
                        .font(Typography.money(14, weight: .semibold)).foregroundStyle(Palette.ink)
                }
                .accessibilityElement(children: .combine)
            }
        }
        .card()
    }
}
