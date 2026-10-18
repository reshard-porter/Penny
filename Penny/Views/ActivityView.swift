import SwiftData
import SwiftUI

struct ActivityView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var state
    @Query(sort: \LedgerEntry.date, order: .reverse) private var entries: [LedgerEntry]
    @Query private var budgets: [BudgetLimit]
    @AppStorage("currency") private var currencyRaw = CurrencyCode.usd.rawValue

    @State private var search = ""
    @State private var kindFilter: EntryKind?
    @State private var categoryFilter: LedgerCategory?
    @State private var editor: EditorTarget?
    @State private var shareItem: ShareItem?

    private var currency: CurrencyCode { CurrencyCode(rawValue: currencyRaw) ?? .usd }
    private var isFiltered: Bool { !query.isEmpty || kindFilter != nil || categoryFilter != nil }
    private var query: String { search.trimmingCharacters(in: .whitespaces).lowercased() }

    private func filtered(_ monthEntries: [LedgerEntry]) -> [LedgerEntry] {
        monthEntries.filter { entry in
            (kindFilter == nil || entry.kind == kindFilter)
                && (categoryFilter == nil || entry.category == categoryFilter)
                && (query.isEmpty
                    || "\(entry.title) \(entry.note) \(entry.category.label)".lowercased().contains(query))
        }
    }

    var body: some View {
        let summary = MonthSummary(month: state.selectedMonth, allEntries: entries, budgets: budgets)
        let visible = filtered(summary.entries)
        let expenseTotal = visible.filter { $0.kind == .expense }.reduce(0) { $0 + $1.amountCents }
        let incomeTotal = visible.filter { $0.kind == .income }.reduce(0) { $0 + $1.amountCents }

        List {
            Section {
                MonthSwitcher()
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }
            Section {
                HStack {
                    Text("\(visible.count) \(visible.count == 1 ? "transaction" : "transactions")")
                        .font(.subheadline.weight(.bold))
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Out \(Money.format(expenseTotal, currency: currency))")
                            .foregroundStyle(Palette.muted)
                        Text("In \(Money.format(incomeTotal, currency: currency))")
                            .foregroundStyle(Palette.green)
                    }
                    .font(.footnote.monospacedDigit())
                }
                if isFiltered {
                    Button("Clear filters", systemImage: "line.3.horizontal.decrease.circle", action: clearFilters)
                        .font(.subheadline)
                }
            }
            Section {
                if visible.isEmpty {
                    ContentUnavailableView {
                        Label(isFiltered ? "No matches just yet" : "Nothing here this month",
                              systemImage: isFiltered ? "magnifyingglass" : "tray")
                    } description: {
                        Text(isFiltered ? "Try a different search or clear your filters."
                                        : "Add a transaction, or switch to another month.")
                    } actions: {
                        if isFiltered {
                            Button("Clear filters", action: clearFilters)
                        } else {
                            Button("Add a transaction") { editor = .new }
                        }
                    }
                    .listRowBackground(Color.clear)
                }
                ForEach(visible) { entry in
                    Button { editor = .edit(entry) } label: { EntryRow(entry: entry, currency: currency) }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                EntryActions.delete(entry, context: context, state: state)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Palette.background)
        .navigationTitle("Activity")
        .searchable(text: $search, prompt: "Description, category or note")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Menu {
                    Picker("Type", selection: $kindFilter) {
                        Text("All types").tag(EntryKind?.none)
                        Text("Expenses").tag(EntryKind?.some(.expense))
                        Text("Income").tag(EntryKind?.some(.income))
                    }
                    Picker("Category", selection: $categoryFilter) {
                        Text("All categories").tag(LedgerCategory?.none)
                        ForEach(LedgerCategory.allCases) { category in
                            Label(category.label, systemImage: category.symbol).tag(LedgerCategory?.some(category))
                        }
                    }
                } label: {
                    Label("Filter", systemImage: isFiltered
                          ? "line.3.horizontal.decrease.circle.fill"
                          : "line.3.horizontal.decrease.circle")
                }
                Button {
                    exportCSV(visible)
                } label: {
                    Label("Export CSV", systemImage: "square.and.arrow.up")
                }
                .disabled(visible.isEmpty)
                Button { editor = .new } label: { Label("Add transaction", systemImage: "plus.circle.fill") }
            }
        }
        .sheet(item: $editor) { target in EntryFormView(target: target) }
        .sheet(item: $shareItem) { item in ShareSheet(url: item.url).lockGuard().presentationDetents([.medium, .large]) }
    }

    private func clearFilters() {
        search = ""
        kindFilter = nil
        categoryFilter = nil
    }

    private func exportCSV(_ rows: [LedgerEntry]) {
        let name = "Penny-\(DateText.monthKey(state.selectedMonth)).csv"
        if let url = CSVExport.file(entries: rows, currency: currency, name: name) {
            shareItem = ShareItem(url: url)
        } else {
            state.show("Couldn’t create the CSV file. Please try again.")
        }
    }
}
