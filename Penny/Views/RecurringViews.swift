import SwiftData
import SwiftUI

struct RecurringListView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var state
    @Query(sort: \RecurringRule.title) private var rules: [RecurringRule]
    @AppStorage("currency") private var currencyRaw = CurrencyCode.usd.rawValue
    @State private var editing: RuleTarget?

    private var currency: CurrencyCode { CurrencyCode(rawValue: currencyRaw) ?? .usd }

    var body: some View {
        List {
            if rules.isEmpty {
                ContentUnavailableView {
                    Label("No recurring transactions", systemImage: "repeat")
                } description: {
                    Text("Add rent, salary or subscriptions once and Penny records them on schedule.")
                } actions: {
                    Button("Add recurring transaction") { editing = .new }
                }
                .listRowBackground(Color.clear)
            }
            ForEach(rules) { rule in
                Button { editing = .edit(rule) } label: { row(rule) }
                    .buttonStyle(.plain)
                    .swipeActions {
                        Button(role: .destructive) {
                            context.delete(rule)
                            try? context.save()
                            state.show("Recurring transaction removed. Past entries were kept.")
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        Button {
                            rule.isActive.toggle()
                            try? context.save()
                            if rule.isActive { RecurringEngine.run(context: context) }
                        } label: {
                            Label(rule.isActive ? "Pause" : "Resume",
                                  systemImage: rule.isActive ? "pause" : "play")
                        }
                        .tint(Palette.blue)
                    }
            }
        }
        .navigationTitle("Recurring")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { editing = .new } label: { Label("Add", systemImage: "plus") }
            }
        }
        .sheet(item: $editing) { target in RuleFormView(target: target) }
    }

    private func row(_ rule: RecurringRule) -> some View {
        HStack(spacing: 12) {
            CategoryBadge(category: rule.category)
            VStack(alignment: .leading, spacing: 3) {
                Text(rule.title).font(.body.weight(.semibold)).foregroundStyle(Palette.ink)
                Text(rule.isActive
                     ? "\(rule.frequency.label) · next \(DateText.long(rule.nextDate))"
                     : "Paused")
                    .font(.footnote).foregroundStyle(Palette.muted)
            }
            Spacer()
            Text((rule.kind == .income ? "+" : "−") + Money.format(rule.amountCents, currency: currency))
                .font(.body.weight(.bold).monospacedDigit())
                .foregroundStyle(rule.kind == .income ? Palette.green : Palette.ink)
        }
        .opacity(rule.isActive ? 1 : 0.55)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

enum RuleTarget: Identifiable {
    case new
    case edit(RecurringRule)

    var id: String {
        switch self {
        case .new: return "new"
        case .edit(let rule): return rule.id.uuidString
        }
    }
}

struct RuleFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var state
    @AppStorage("currency") private var currencyRaw = CurrencyCode.usd.rawValue

    let target: RuleTarget

    @State private var kind: EntryKind = .expense
    @State private var amountText = ""
    @State private var title = ""
    @State private var category: LedgerCategory = .bills
    @State private var frequency: RepeatFrequency = .monthly
    @State private var startDate = Date()
    @State private var note = ""
    @State private var isActive = true
    @State private var showErrors = false
    @State private var loaded = false

    private var existing: RecurringRule? {
        if case .edit(let rule) = target { return rule }
        return nil
    }

    private var currency: CurrencyCode { CurrencyCode(rawValue: currencyRaw) ?? .usd }
    private var cents: Int? { Money.parse(amountText) }
    private var trimmedTitle: String { title.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var isValid: Bool { cents != nil && !trimmedTitle.isEmpty && trimmedTitle.count <= 70 && note.count <= 280 }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Type", selection: $kind) {
                        Text("Expense").tag(EntryKind.expense)
                        Text("Income").tag(EntryKind.income)
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    HStack(spacing: 8) {
                        Text(currency.symbol).font(.title2.weight(.bold)).foregroundStyle(Palette.muted)
                        TextField("0.00", text: $amountText)
                            .keyboardType(.decimalPad)
                            .font(.title.weight(.heavy).monospacedDigit())
                            .accessibilityLabel("Amount")
                    }
                    TextField("Description, e.g. Apartment rent", text: $title)
                    if kind == .expense {
                        Picker("Category", selection: $category) {
                            ForEach(LedgerCategory.expenseCases) { option in
                                Label(option.label, systemImage: option.symbol).tag(option)
                            }
                        }
                    }
                    if showErrors && !isValid {
                        Text("Enter an amount from 0.01 to 9,999,999.99 and a description up to 70 characters.")
                            .font(.footnote).foregroundStyle(Palette.red)
                    }
                }

                Section {
                    Picker("Repeats", selection: $frequency) {
                        ForEach(RepeatFrequency.allCases) { option in Text(option.label).tag(option) }
                    }
                    DatePicker(existing == nil ? "Starting" : "Started", selection: $startDate, displayedComponents: .date)
                        .disabled(existing != nil)
                    if existing != nil {
                        Toggle("Active", isOn: $isActive)
                    }
                } footer: {
                    if let rule = existing {
                        Text("Changes apply to future entries. \(rule.generatedCount) already recorded \(rule.generatedCount == 1 ? "stays" : "stay") as they are.")
                    } else {
                        Text("If the start date is today or earlier, Penny records the due entries right away.")
                    }
                }

                Section("Note (optional)") {
                    TextField("Anything you’d like to remember", text: $note, axis: .vertical)
                        .lineLimit(1...4)
                }
            }
            .navigationTitle(existing == nil ? "New recurring" : "Edit recurring")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save", action: save).fontWeight(.bold) }
            }
            .onAppear(perform: load)
        }
        .lockGuard()
    }

    private func load() {
        guard !loaded, let rule = existing else { return }
        loaded = true
        kind = rule.kind
        amountText = Money.inputText(rule.amountCents)
        title = rule.title
        category = rule.kind == .income ? .bills : rule.category
        frequency = rule.frequency
        startDate = rule.startDate
        note = rule.note
        isActive = rule.isActive
    }

    private func save() {
        guard isValid, let cents else {
            showErrors = true
            return
        }
        let finalCategory: LedgerCategory = kind == .income ? .income : category
        let cleanNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        if let rule = existing {
            rule.title = trimmedTitle
            rule.amountCents = cents
            rule.kind = kind
            rule.category = finalCategory
            rule.note = cleanNote
            if rule.frequency != frequency {
                // Restart the schedule from the next due date so past entries keep their dates.
                rule.startDate = rule.nextDate
                rule.generatedCount = 0
                rule.frequency = frequency
            }
            rule.isActive = isActive
            state.show("Recurring transaction updated.")
        } else {
            context.insert(RecurringRule(title: trimmedTitle, amountCents: cents, kind: kind,
                                         category: finalCategory, note: cleanNote,
                                         frequency: frequency, startDate: startDate))
            state.show("Recurring transaction added.")
        }
        try? context.save()
        RecurringEngine.run(context: context)
        dismiss()
    }
}
