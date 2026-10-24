import SwiftData
import SwiftUI

struct ActivityView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var state
    @Query(sort: \LedgerEntry.date, order: .reverse) private var entries: [LedgerEntry]
    @AppStorage("currency") private var currencyRaw = CurrencyCode.usd.rawValue

    @State private var search = ""
    @State private var scope: SearchScope = .month
    @State private var filter: QuickFilter = .all
    @State private var categoryFilter: LedgerCategory?
    @State private var shareItem: ShareItem?

    enum SearchScope: String, CaseIterable, Identifiable {
        case month, all
        var id: String { rawValue }
        var label: String { self == .month ? "This month" : "All time" }
    }

    enum QuickFilter: String, CaseIterable, Identifiable {
        case all, expenses, income, recurring, receipts
        var id: String { rawValue }
        var label: String {
            switch self {
            case .all: return "All"
            case .expenses: return "Expenses"
            case .income: return "Income"
            case .recurring: return "Recurring"
            case .receipts: return "Receipts"
            }
        }
        var symbol: String? {
            switch self {
            case .all: return nil
            case .expenses: return "arrow.up.right"
            case .income: return "arrow.down.left"
            case .recurring: return "repeat"
            case .receipts: return "paperclip"
            }
        }
    }

    private var currency: CurrencyCode { CurrencyCode(rawValue: currencyRaw) ?? .usd }
    private var query: String { search.trimmingCharacters(in: .whitespaces).lowercased() }
    private var isFiltered: Bool { !query.isEmpty || filter != .all || categoryFilter != nil }

    private func matches(_ entry: LedgerEntry) -> Bool {
        let passesQuick: Bool = {
            switch filter {
            case .all: return true
            case .expenses: return entry.kind == .expense
            case .income: return entry.kind == .income
            case .recurring: return entry.ruleID != nil
            case .receipts: return entry.hasReceipt
            }
        }()
        guard passesQuick else { return false }
        if let categoryFilter, entry.category != categoryFilter { return false }
        if query.isEmpty { return true }
        let haystack = "\(entry.title) \(entry.note) \(entry.category.label) \(Money.inputText(entry.amountCents))".lowercased()
        return haystack.contains(query)
    }

    private var visible: [LedgerEntry] {
        let calendar = Calendar.current
        let start = calendar.startOfMonth(for: state.selectedMonth)
        let end = calendar.month(offset: 1, from: start)
        return entries.filter { entry in
            (scope == .all || (entry.date >= start && entry.date < end)) && matches(entry)
        }
    }

    private struct DayGroup: Identifiable {
        let day: Date
        let entries: [LedgerEntry]
        var id: Date { day }
        var net: Int { entries.reduce(0) { $0 + $1.signedCents } }
    }

    private func grouped(_ list: [LedgerEntry]) -> [DayGroup] {
        let calendar = Calendar.current
        var groups: [DayGroup] = []
        var currentDay: Date?
        var bucket: [LedgerEntry] = []
        for entry in list {
            let day = calendar.startOfDay(for: entry.date)
            if day != currentDay, let previous = currentDay {
                groups.append(DayGroup(day: previous, entries: bucket))
                bucket = []
            }
            currentDay = day
            bucket.append(entry)
        }
        if let currentDay { groups.append(DayGroup(day: currentDay, entries: bucket)) }
        return groups
    }

    var body: some View {
        let list = visible
        let groups = grouped(list)
        let expenseTotal = list.filter { $0.kind == .expense }.reduce(0) { $0 + $1.amountCents }
        let incomeTotal = list.filter { $0.kind == .income }.reduce(0) { $0 + $1.amountCents }

        List {
            Section {
                VStack(spacing: 14) {
                    if scope == .month { MonthSwitcher() }
                    summaryCard(count: list.count, income: incomeTotal, expenses: expenseTotal)
                    filterBar
                }
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }

            if groups.isEmpty {
                Section {
                    EmptyStateCard(symbol: isFiltered ? "magnifyingglass" : "tray",
                                   title: isFiltered ? "No matches" : "Nothing here yet",
                                   message: isFiltered ? "Try another search or clear your filters."
                                                       : "Add a transaction, or switch to another month.",
                                   actionTitle: isFiltered ? nil : "Add a transaction") { state.add() }
                        .card()
                    if isFiltered {
                        Button("Clear filters", action: clearFilters)
                            .frame(maxWidth: .infinity)
                            .font(.subheadline.weight(.semibold))
                    }
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }

            ForEach(groups) { group in
                Section {
                    ForEach(group.entries) { entry in
                        Button { state.editor = .edit(entry) } label: {
                            EntryRow(entry: entry, currency: currency, showDate: false)
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(Palette.surface)
                        .listRowSeparatorTint(Palette.line)
                        .alignmentGuide(.listRowSeparatorLeading) { _ in 58 }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                EntryActions.delete(entry, context: context, state: state)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .swipeActions(edge: .leading) {
                            Button {
                                state.editor = .duplicate(entry)
                            } label: {
                                Label("Duplicate", systemImage: "plus.square.on.square")
                            }
                            .tint(Palette.blue)
                        }
                        .contextMenu {
                            Button { state.editor = .edit(entry) } label: { Label("Edit", systemImage: "pencil") }
                            Button { state.editor = .duplicate(entry) } label: {
                                Label("Duplicate", systemImage: "plus.square.on.square")
                            }
                            Button { filterBy(entry.category) } label: {
                                Label("Show all \(entry.category.label)", systemImage: entry.category.symbol)
                            }
                            Divider()
                            Button(role: .destructive) {
                                EntryActions.delete(entry, context: context, state: state)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                } header: {
                    HStack {
                        Text(dayTitle(group.day))
                        Spacer()
                        Text((group.net >= 0 ? "+" : "") + Money.format(group.net, currency: currency))
                            .monospacedDigit()
                            .foregroundStyle(group.net >= 0 ? Palette.green : Palette.muted)
                    }
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Palette.muted)
                    .textCase(nil)
                }
            }

            Color.clear.frame(height: 70)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
        }
        .listStyle(.insetGrouped)
        .listSectionSpacing(14)
        .scrollContentBackground(.hidden)
        .pennyBackground()
        .navigationTitle("Activity")
        .searchable(text: $search, prompt: "Search descriptions, notes, amounts")
        .searchScopes($scope) {
            ForEach(SearchScope.allCases) { option in Text(option.label).tag(option) }
        }
        .animation(.snappy, value: filter)
        .animation(.snappy, value: categoryFilter)
        .overlay(alignment: .bottomTrailing) { FloatingAddButton() }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Menu {
                    Picker("Category", selection: $categoryFilter) {
                        Text("All categories").tag(LedgerCategory?.none)
                        ForEach(LedgerCategory.allCases) { category in
                            Label(category.label, systemImage: category.symbol).tag(LedgerCategory?.some(category))
                        }
                    }
                } label: {
                    Label("Category", systemImage: categoryFilter == nil
                          ? "line.3.horizontal.decrease.circle"
                          : "line.3.horizontal.decrease.circle.fill")
                }
                Button {
                    exportCSV(list)
                } label: {
                    Label("Export CSV", systemImage: "square.and.arrow.up")
                }
                .disabled(list.isEmpty)
            }
        }
        .sheet(item: $shareItem) { item in
            ShareSheet(url: item.url).lockGuard().presentationDetents([.medium, .large])
        }
    }

    private func summaryCard(count: Int, income: Int, expenses: Int) -> some View {
        HStack(spacing: 0) {
            summaryValue("Transactions", "\(count)", color: Palette.ink)
            Spacer()
            summaryValue("Money in", Money.short(income, currency: currency), color: Palette.green)
            Spacer()
            summaryValue("Money out", Money.short(expenses, currency: currency), color: Palette.ink)
        }
        .card(padding: 16, radius: 20)
    }

    private func summaryValue(_ label: String, _ value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label).font(.caption).foregroundStyle(Palette.muted)
            Text(value).font(Typography.money(18, weight: .bold)).foregroundStyle(color)
                .lineLimit(1).minimumScaleFactor(0.6)
                .contentTransition(.numericText())
        }
        .accessibilityElement(children: .combine)
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(QuickFilter.allCases) { option in
                    Chip(title: option.label, symbol: option.symbol, isSelected: filter == option) {
                        filter = option
                    }
                }
                if let categoryFilter {
                    Chip(title: categoryFilter.label, symbol: "xmark", isSelected: true, tint: categoryFilter.color) {
                        self.categoryFilter = nil
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .scrollClipDisabled()
    }

    private func dayTitle(_ day: Date) -> String {
        let relative = DateText.relativeDay(day)
        if scope == .all && !Calendar.current.isDate(day, equalTo: Date(), toGranularity: .year) {
            return day.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day().year())
        }
        return relative
    }

    private func filterBy(_ category: LedgerCategory) {
        categoryFilter = category
    }

    private func clearFilters() {
        search = ""
        filter = .all
        categoryFilter = nil
    }

    private func exportCSV(_ rows: [LedgerEntry]) {
        let name = scope == .all ? "Penny-transactions.csv" : "Penny-\(DateText.monthKey(state.selectedMonth)).csv"
        if let url = CSVExport.file(entries: rows, currency: currency, name: name) {
            shareItem = ShareItem(url: url)
        } else {
            state.show("Couldn’t create the CSV file. Please try again.", symbol: "exclamationmark.triangle.fill")
        }
    }
}

/// Shared delete-with-undo used by the form and the Activity list.
enum EntryActions {
    @MainActor
    static func delete(_ entry: LedgerEntry, context: ModelContext, state: AppState) {
        let snapshot = (title: entry.title, amount: entry.amountCents, kind: entry.kind, category: entry.category,
                        date: entry.date, note: entry.note, ruleID: entry.ruleID, receipt: entry.receiptData,
                        isSample: entry.isSample)
        context.delete(entry)
        try? context.save()
        Haptics.warning()
        state.show("“\(snapshot.title)” deleted.", symbol: "trash.fill") {
            context.insert(LedgerEntry(title: snapshot.title, amountCents: snapshot.amount, kind: snapshot.kind,
                                       category: snapshot.category, date: snapshot.date, note: snapshot.note,
                                       isSample: snapshot.isSample, ruleID: snapshot.ruleID,
                                       receiptData: snapshot.receipt))
            try? context.save()
        }
    }
}
