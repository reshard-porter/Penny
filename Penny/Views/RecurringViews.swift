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
        let active = rules.filter(\.isActive)
        let monthlyOut = active.filter { $0.kind == .expense }.reduce(0) { $0 + $1.monthlyCents }
        let monthlyIn = active.filter { $0.kind == .income }.reduce(0) { $0 + $1.monthlyCents }
        let sorted = rules.sorted { lhs, rhs in
            if lhs.isActive != rhs.isActive { return lhs.isActive }
            return lhs.nextDate < rhs.nextDate
        }

        List {
            if !rules.isEmpty {
                Section {
                    HStack(spacing: 0) {
                        VStack(alignment: .leading, spacing: 4) {
                            Eyebrow(text: "Fixed costs / month")
                            Text(Money.short(monthlyOut, currency: currency))
                                .font(Typography.money(30, weight: .heavy)).foregroundStyle(.white)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            Eyebrow(text: "Recurring income")
                            Text(Money.short(monthlyIn, currency: currency))
                                .font(Typography.money(20, weight: .bold)).foregroundStyle(Palette.lime)
                        }
                    }
                    .heroCard(padding: 20, radius: 24)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }
            }

            if rules.isEmpty {
                Section {
                    EmptyStateCard(symbol: "repeat", title: "Nothing on repeat",
                                   message: "Add rent, salary or subscriptions once and Penny records them on schedule.",
                                   actionTitle: "Add recurring") { editing = .new }
                        .listRowBackground(Color.clear)
                }
            }

            Section {
                ForEach(sorted) { rule in
                    Button { editing = .edit(rule) } label: { row(rule) }
                        .buttonStyle(.plain)
                        .listRowBackground(Palette.surface)
                        .swipeActions {
                            Button(role: .destructive) {
                                context.delete(rule)
                                try? context.save()
                                state.show("Recurring transaction removed. Past entries were kept.", symbol: "trash.fill")
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            Button {
                                rule.isActive.toggle()
                                try? context.save()
                                if rule.isActive { RecurringEngine.run(context: context) }
                                Haptics.tap()
                            } label: {
                                Label(rule.isActive ? "Pause" : "Resume",
                                      systemImage: rule.isActive ? "pause.fill" : "play.fill")
                            }
                            .tint(Palette.blue)
                        }
                }
            } footer: {
                if !rules.isEmpty {
                    Text("Penny records due entries when you open the app. Swipe to pause or delete.")
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .pennyBackground()
        .navigationTitle("Recurring")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { editing = .new } label: { Label("Add", systemImage: "plus.circle.fill") }
            }
        }
        .sheet(item: $editing) { target in RuleFormView(target: target) }
    }

    private func row(_ rule: RecurringRule) -> some View {
        HStack(spacing: 14) {
            CategoryBadge(category: rule.category, size: 44)
                .saturation(rule.isActive ? 1 : 0)
            VStack(alignment: .leading, spacing: 3) {
                Text(rule.title).font(.body.weight(.semibold)).foregroundStyle(Palette.ink).lineLimit(1)
                Text(rule.isActive
                     ? "\(rule.frequency.shortLabel) · next \(DateText.dueText(rule.nextDate))"
                     : "Paused")
                    .font(.footnote).foregroundStyle(Palette.muted)
            }
            Spacer()
            Text(Money.signed(rule.amountCents, kind: rule.kind, currency: currency))
                .font(Typography.money(16, weight: .bold))
                .foregroundStyle(rule.kind == .income ? Palette.green : Palette.ink)
        }
        .padding(.vertical, 4)
        .opacity(rule.isActive ? 1 : 0.6)
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
    @State private var confirmDelete = false
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
                    PillPicker(options: [(EntryKind.expense, "Expense"), (EntryKind.income, "Income")], selection: $kind)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                }

                Section {
                    HStack(spacing: 8) {
                        Text(currency.symbol).font(.title2.weight(.bold)).foregroundStyle(Palette.muted)
                        TextField("0.00", text: $amountText)
                            .keyboardType(.decimalPad)
                            .font(Typography.money(30, weight: .heavy))
                            .accessibilityLabel("Amount")
                    }
                    TextField("Description, e.g. Apartment rent", text: $title)
                    Picker("Category", selection: $category) {
                        ForEach(LedgerCategory.cases(for: kind)) { option in
                            Label(option.label, systemImage: option.symbol).tag(option)
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
                    if let cents, frequency != .monthly {
                        LabeledContent("About per month",
                                       value: Money.format(Int((Double(cents) * frequency.perMonth).rounded()), currency: currency))
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

                if existing != nil {
                    Section {
                        Button("Delete recurring transaction", role: .destructive) { confirmDelete = true }
                    }
                }
            }
            .navigationTitle(existing == nil ? "New recurring" : "Edit recurring")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save", action: save).fontWeight(.bold) }
            }
            .onAppear(perform: load)
            .onChange(of: kind) { _, newKind in
                if !LedgerCategory.cases(for: newKind).contains(category) {
                    category = newKind == .income ? .income : .bills
                }
            }
            .confirmationDialog("Delete this recurring transaction?", isPresented: $confirmDelete,
                                titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    if let rule = existing {
                        context.delete(rule)
                        try? context.save()
                        state.show("Recurring transaction removed. Past entries were kept.", symbol: "trash.fill")
                    }
                    dismiss()
                }
            }
        }
        .lockGuard()
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        guard let rule = existing else { return }
        kind = rule.kind
        amountText = Money.inputText(rule.amountCents)
        title = rule.title
        category = rule.category
        frequency = rule.frequency
        startDate = rule.startDate
        note = rule.note
        isActive = rule.isActive
    }

    private func save() {
        guard isValid, let cents else {
            showErrors = true
            Haptics.warning()
            return
        }
        let finalCategory = LedgerCategory.normalized(category, for: kind)
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
            rule.isSample = false
            state.show("Recurring transaction updated.")
        } else {
            context.insert(RecurringRule(title: trimmedTitle, amountCents: cents, kind: kind,
                                         category: finalCategory, note: cleanNote,
                                         frequency: frequency, startDate: startDate))
            state.show("Recurring transaction added.", symbol: "repeat")
        }
        try? context.save()
        RecurringEngine.run(context: context)
        Haptics.success()
        dismiss()
    }
}
