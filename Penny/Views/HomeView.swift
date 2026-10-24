import Charts
import SwiftData
import SwiftUI

struct HomeView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var state
    @Query(sort: \LedgerEntry.date, order: .reverse) private var entries: [LedgerEntry]
    @Query private var budgets: [BudgetLimit]
    @Query(filter: #Predicate<RecurringRule> { $0.isActive }) private var rules: [RecurringRule]
    @Query(filter: #Predicate<SavingsGoal> { !$0.isArchived }, sort: \SavingsGoal.createdAt) private var goals: [SavingsGoal]
    @Query private var contributions: [GoalContribution]
    @AppStorage("currency") private var currencyRaw = CurrencyCode.usd.rawValue
    @State private var confirmRemoveSamples = false
    @State private var showRecurring = false

    private var currency: CurrencyCode { CurrencyCode(rawValue: currencyRaw) ?? .usd }

    var body: some View {
        let summary = MonthSummary(month: state.selectedMonth, allEntries: entries, budgets: budgets)
        let upcoming = Array(RecurringEngine.upcoming(rules: rules, days: 30).prefix(4))
        let saved = GoalMath.saved(contributions)

        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 18) {
                    header
                    if entries.contains(where: { $0.isSample }) {
                        SampleBanner { confirmRemoveSamples = true }
                    }
                    MonthSwitcher()
                    BudgetHero(summary: summary, currency: currency) {
                        state.planSegment = .budgets
                        state.selectedTab = .plan
                    }
                    HStack(spacing: 12) {
                        StatTile(label: "Money in", value: Money.short(summary.income, currency: currency),
                                 symbol: "arrow.down.left", tint: Palette.green)
                        StatTile(label: "Money out", value: Money.short(summary.expenses, currency: currency),
                                 symbol: "arrow.up.right", tint: Color(hex: 0xEA580C))
                        StatTile(label: "Net", value: Money.short(summary.net, currency: currency),
                                 symbol: "plusminus", tint: Palette.blue)
                    }
                    WeekChartCard(summary: summary, currency: currency)
                        .id("more")
                    if !upcoming.isEmpty {
                        UpcomingCard(items: upcoming, currency: currency) { showRecurring = true }
                    }
                    if !goals.isEmpty {
                        GoalsStrip(goals: goals, saved: saved, currency: currency) {
                            state.planSegment = .goals
                            state.selectedTab = .plan
                        }
                    }
                    CategoryBreakdownCard(summary: summary, currency: currency, limit: 5)
                    recentActivity(summary)
                        .id("end")
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 96)
            }
            .screenshotScroll(proxy)
        }
        .pennyBackground()
        .overlay(alignment: .bottomTrailing) { FloatingAddButton() }
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(isPresented: $showRecurring) { RecurringListView() }
        .confirmationDialog("Clear all sample data?", isPresented: $confirmRemoveSamples, titleVisibility: .visible) {
            Button("Clear sample data", role: .destructive) { removeSamples() }
        } message: {
            Text("Sample transactions, goals and bills are removed. Anything you added yourself is kept.")
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(Date().formatted(.dateTime.weekday(.wide).month(.wide).day()).uppercased())
                    .font(Typography.eyebrow)
                    .tracking(1.2)
                    .foregroundStyle(Palette.muted)
                Text(DateText.greeting())
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            Spacer()
            Button {
                state.selectedTab = .settings
            } label: {
                BrandMark(size: 46)
            }
            .buttonStyle(PressableStyle(scale: 0.92))
            .accessibilityLabel("Settings")
        }
        .padding(.top, 6)
    }

    private func recentActivity(_ summary: MonthSummary) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Recent activity", subtitle: nil,
                          actionTitle: summary.entries.isEmpty ? nil : "See all") {
                state.selectedTab = .activity
            }
            if summary.entries.isEmpty {
                EmptyStateCard(symbol: "sparkles",
                               title: "A clean slate",
                               message: "Add your first expense or income and Penny will do the math.",
                               actionTitle: "Add a transaction") { state.add() }
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(summary.entries.prefix(5).enumerated()), id: \.element.id) { index, entry in
                        if index > 0 { Divider().padding(.leading, 58) }
                        Button { state.editor = .edit(entry) } label: { EntryRow(entry: entry, currency: currency) }
                            .buttonStyle(PressableStyle(scale: 0.98))
                    }
                }
            }
        }
        .card()
    }

    private func removeSamples() {
        SampleData.remove(from: context)
        state.show("Sample data cleared. Your fresh start is ready.", symbol: "sparkles")
    }
}

// MARK: - Budget hero

struct BudgetHero: View {
    let summary: MonthSummary
    let currency: CurrencyCode
    let onManage: () -> Void

    var body: some View {
        let calendar = Calendar.current
        let isCurrent = summary.isCurrentMonth()
        let hasBudget = summary.hasBudget
        let over = hasBudget && summary.remaining < 0
        let ratio = summary.budget == 0 ? 0 : Double(summary.budgetedSpending) / Double(summary.budget)
        let elapsed = summary.elapsedDays(today: Date())
        let pace = Double(elapsed) / Double(max(summary.daysInMonth, 1))
        let daysLeft = isCurrent ? summary.daysInMonth - calendar.component(.day, from: Date()) + 1 : 0
        let perDay = daysLeft > 0 && summary.remaining > 0 ? summary.remaining / daysLeft : 0
        let ahead = hasBudget && !over && isCurrent && ratio > pace + 0.05

        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Eyebrow(text: hasBudget ? (over ? "Over plan in \(DateText.monthName(summary.month))" : "Left to spend in \(DateText.monthName(summary.month))")
                                        : "Spent in \(DateText.monthName(summary.month))")
                Spacer()
                statusPill(over: over, ahead: ahead, hasBudget: hasBudget)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(Money.format(hasBudget ? abs(summary.remaining) : summary.expenses, currency: currency))
                    .font(Typography.money(50, weight: .heavy))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .contentTransition(.numericText(value: Double(summary.remaining)))
                Text(hasBudget
                     ? "\(Money.short(summary.budgetedSpending, currency: currency)) spent of \(Money.short(summary.budget, currency: currency)) planned"
                     : "Set category budgets to see what’s left.")
                    .font(.subheadline)
                    .foregroundStyle(Palette.heroText)
            }
            .accessibilityElement(children: .combine)

            if hasBudget {
                VStack(alignment: .leading, spacing: 8) {
                    ProgressBar(value: ratio,
                                tint: over ? AnyShapeStyle(Gradients.danger) : AnyShapeStyle(Gradients.lime),
                                track: Palette.heroTrack, height: 10,
                                marker: isCurrent ? pace : nil)
                    HStack {
                        Text("\(Int((ratio * 100).rounded()))% used")
                        Spacer()
                        if isCurrent {
                            Text("\(daysLeft) \(daysLeft == 1 ? "day" : "days") left")
                        } else {
                            Text(summary.month > Date() ? "Upcoming month" : "Month complete")
                        }
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Palette.heroText)
                }
            }

            Rectangle().fill(.white.opacity(0.12)).frame(height: 1)

            HStack(spacing: 0) {
                heroStat(isCurrent ? "Safe per day" : "Daily average",
                         isCurrent ? Money.short(perDay, currency: currency)
                                   : Money.short(summary.expenses / max(elapsed, 1), currency: currency))
                Spacer()
                heroStat("Recurring", Money.short(summary.recurringExpenses, currency: currency))
                Spacer()
                Button {
                    Haptics.tap()
                    onManage()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "slider.horizontal.3")
                        Text("Plan")
                    }
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Palette.navy)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Gradients.lime, in: Capsule())
                }
                .buttonStyle(PressableStyle())
            }
        }
        .heroCard()
    }

    private func statusPill(over: Bool, ahead: Bool, hasBudget: Bool) -> some View {
        let (text, symbol, color): (String, String, Color) = {
            if !hasBudget { return ("No plan", "circle.dashed", .white.opacity(0.85)) }
            if over { return ("Over plan", "exclamationmark.triangle.fill", Color(hex: 0xFF8A7A)) }
            if ahead { return ("Spending fast", "hare.fill", Color(hex: 0xFBBF24)) }
            return ("On track", "checkmark.seal.fill", Palette.lime)
        }()
        return Label(text, systemImage: symbol)
            .font(.caption.weight(.bold))
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(color.opacity(0.16), in: Capsule())
            .overlay(Capsule().strokeBorder(color.opacity(0.35), lineWidth: 0.5))
    }

    private func heroStat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label).font(.caption).foregroundStyle(Palette.heroFaint)
            Text(value).font(Typography.money(17, weight: .bold)).foregroundStyle(.white)
                .lineLimit(1).minimumScaleFactor(0.7)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Stat tile

struct StatTile: View {
    let label: String
    let value: String
    let symbol: String
    var tint: Color = Palette.blue

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SymbolBadge(symbol: symbol, color: tint, size: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.caption).foregroundStyle(Palette.muted)
                Text(value)
                    .font(Typography.money(17, weight: .bold))
                    .foregroundStyle(Palette.ink)
                    .minimumScaleFactor(0.55)
                    .lineLimit(1)
                    .contentTransition(.numericText())
            }
        }
        .card(padding: 14, radius: 20)
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
        let average = values.isEmpty ? 0 : total / values.count
        let picked = selectedDay.flatMap { selection in
            values.first { Calendar.current.isDate($0.day, inSameDayAs: selection) }
        }
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(picked.map { DateText.relativeDay($0.day) } ?? "Last \(values.count) days")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Palette.muted)
                    Text(Money.format(picked?.cents ?? total, currency: currency))
                        .font(Typography.money(28, weight: .heavy))
                        .foregroundStyle(Palette.ink)
                        .contentTransition(.numericText())
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Daily avg").font(.caption).foregroundStyle(Palette.muted)
                    Text(Money.short(average, currency: currency))
                        .font(Typography.money(15, weight: .bold)).foregroundStyle(Palette.ink)
                }
            }
            Chart {
                ForEach(values) { value in
                    BarMark(x: .value("Day", value.day, unit: .day),
                            y: .value("Spent", Double(value.cents) / 100),
                            width: .ratio(0.55))
                        .foregroundStyle(picked == nil || picked?.day == value.day
                                         ? AnyShapeStyle(Gradients.blue)
                                         : AnyShapeStyle(Palette.blue.opacity(0.25)))
                        .cornerRadius(7)
                }
                if average > 0 {
                    RuleMark(y: .value("Average", Double(average) / 100))
                        .foregroundStyle(Palette.faint)
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                }
            }
            .chartXSelection(value: $selectedDay)
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { _ in
                    AxisValueLabel(format: .dateTime.weekday(.abbreviated), centered: true)
                }
            }
            .chartYAxis {
                AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 3]))
                    AxisValueLabel {
                        if let amount = value.as(Double.self) {
                            Text(Money.compact(Int(amount * 100), currency: currency))
                        }
                    }
                }
            }
            .frame(height: 170)
            .animation(.snappy, value: selectedDay)
        }
        .card()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Spending in the last \(values.count) days")
    }
}

// MARK: - Upcoming bills

struct UpcomingCard: View {
    let items: [UpcomingItem]
    let currency: CurrencyCode
    let onManage: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Coming up", subtitle: "Recurring in the next 30 days",
                          actionTitle: "Manage", action: onManage)
            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    if index > 0 { Divider().padding(.leading, 58) }
                    HStack(spacing: 14) {
                        CategoryBadge(category: item.rule.category, size: 44)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(item.rule.title).font(.body.weight(.semibold)).foregroundStyle(Palette.ink)
                                .lineLimit(1)
                            Text("\(DateText.dueText(item.date).capitalizedFirst) · \(DateText.short(item.date))")
                                .font(.footnote).foregroundStyle(dueColor(item.date))
                        }
                        Spacer()
                        Text(Money.signed(item.rule.amountCents, kind: item.rule.kind, currency: currency))
                            .font(Typography.money(16, weight: .bold))
                            .foregroundStyle(item.rule.kind == .income ? Palette.green : Palette.ink)
                    }
                    .padding(.vertical, 6)
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .card()
    }

    private func dueColor(_ date: Date) -> Color {
        Calendar.current.daysFromToday(to: date) <= 2 ? Palette.orange : Palette.muted
    }
}

extension String {
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}

// MARK: - Goals strip

struct GoalsStrip: View {
    let goals: [SavingsGoal]
    let saved: [UUID: Int]
    let currency: CurrencyCode
    let onSeeAll: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Savings goals", subtitle: nil, actionTitle: "See all", action: onSeeAll)
                .padding(.horizontal, 4)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(goals) { goal in
                        let amount = saved[goal.id] ?? 0
                        Button(action: onSeeAll) {
                            VStack(alignment: .leading, spacing: 12) {
                                ZStack {
                                    RingProgress(value: GoalMath.progress(saved: amount, target: goal.targetCents),
                                                 lineWidth: 7, colors: goal.color.colors, track: Palette.line)
                                    Image(systemName: goal.symbol)
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundStyle(goal.color.main)
                                }
                                .frame(width: 58, height: 58)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(goal.name).font(.subheadline.weight(.bold)).foregroundStyle(Palette.ink)
                                        .lineLimit(1)
                                    Text("\(Money.compact(amount, currency: currency)) of \(Money.compact(goal.targetCents, currency: currency))")
                                        .font(.caption).foregroundStyle(Palette.muted)
                                }
                            }
                            .frame(width: 132, alignment: .leading)
                            .card(padding: 14, radius: 22)
                        }
                        .buttonStyle(PressableStyle())
                        .accessibilityLabel("\(goal.name), \(Int(GoalMath.progress(saved: amount, target: goal.targetCents) * 100)) percent saved")
                    }
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 4)
            }
            .scrollClipDisabled()
        }
    }
}

// MARK: - Category breakdown

struct CategoryBreakdownCard: View {
    let summary: MonthSummary
    let currency: CurrencyCode
    var limit = 5

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Where it went", subtitle: "Top categories this month")
            let categories = Array(summary.rankedCategories.prefix(limit))
            if categories.isEmpty {
                Text("Add an expense to see your category breakdown.")
                    .font(.subheadline).foregroundStyle(Palette.muted)
                    .padding(.vertical, 8)
            }
            ForEach(categories) { category in
                let cents = summary.spent(category)
                let share = summary.expenses == 0 ? 0 : Double(cents) / Double(summary.expenses)
                HStack(spacing: 12) {
                    CategoryBadge(category: category, size: 38)
                    VStack(alignment: .leading, spacing: 7) {
                        HStack {
                            Text(category.label).font(.subheadline.weight(.semibold)).foregroundStyle(Palette.ink)
                            Spacer()
                            Text(Money.format(cents, currency: currency))
                                .font(Typography.money(15, weight: .bold)).foregroundStyle(Palette.ink)
                        }
                        HStack(spacing: 8) {
                            ProgressBar(value: share, tint: AnyShapeStyle(Gradients.tint(category.color)),
                                        track: Palette.surfaceRaised, height: 6)
                            Text("\(Int((share * 100).rounded()))%")
                                .font(.caption.weight(.semibold).monospacedDigit())
                                .foregroundStyle(Palette.muted)
                                .frame(width: 36, alignment: .trailing)
                        }
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(category.label), \(Money.format(cents, currency: currency)), \(Int((share * 100).rounded())) percent of spending")
            }
        }
        .card()
    }
}
