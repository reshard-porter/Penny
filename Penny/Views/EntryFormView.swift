import SwiftData
import SwiftUI

/// Add or edit a transaction. New transactions can be set to repeat.
struct EntryFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var state
    @AppStorage("currency") private var currencyRaw = CurrencyCode.usd.rawValue

    let target: EditorTarget

    @State private var kind: EntryKind = .expense
    @State private var amountText = ""
    @State private var title = ""
    @State private var category: LedgerCategory = .groceries
    @State private var date = Date()
    @State private var note = ""
    @State private var repeatChoice: RepeatFrequency?
    @State private var showErrors = false
    @State private var confirmDelete = false
    @State private var loaded = false

    private var existing: LedgerEntry? {
        if case .edit(let entry) = target { return entry }
        return nil
    }

    private var currency: CurrencyCode { CurrencyCode(rawValue: currencyRaw) ?? .usd }
    private var cents: Int? { Money.parse(amountText) }
    private var trimmedTitle: String { title.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var amountError: String? { cents == nil ? "Enter an amount from 0.01 to 9,999,999.99." : nil }
    private var titleError: String? {
        if trimmedTitle.isEmpty { return "Add a description so you can recognize this later." }
        if trimmedTitle.count > 70 { return "Keep the description under 70 characters." }
        return nil
    }
    private var noteError: String? { note.count > 280 ? "Notes can be up to 280 characters." : nil }
    private var isValid: Bool { amountError == nil && titleError == nil && noteError == nil }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Type", selection: $kind) {
                        Label("Expense", systemImage: "arrow.up.right").tag(EntryKind.expense)
                        Label("Income", systemImage: "arrow.down.left").tag(EntryKind.income)
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }

                Section {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(currency.symbol)
                            .font(.title.weight(.bold))
                            .foregroundStyle(Palette.muted)
                        TextField("0.00", text: $amountText)
                            .keyboardType(.decimalPad)
                            .font(.system(size: 36, weight: .heavy, design: .rounded).monospacedDigit())
                            .accessibilityLabel("Amount")
                    }
                    if showErrors, let amountError {
                        Text(amountError).font(.footnote).foregroundStyle(Palette.red)
                    }
                } header: {
                    Text("Amount")
                }

                Section {
                    TextField(kind == .income ? "e.g. Monthly salary" : "e.g. Weekly groceries", text: $title)
                        .textInputAutocapitalization(.sentences)
                    if showErrors, let titleError {
                        Text(titleError).font(.footnote).foregroundStyle(Palette.red)
                    }
                } header: {
                    Text(kind == .income ? "Where did it come from?" : "What was it for?")
                }

                if kind == .expense {
                    Section("Category") {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 8)], spacing: 8) {
                            ForEach(LedgerCategory.expenseCases) { option in
                                categoryChip(option)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section {
                    DatePicker("Date", selection: $date, in: dateRange, displayedComponents: .date)
                    if existing == nil {
                        Picker("Repeat", selection: $repeatChoice) {
                            Text("Never").tag(RepeatFrequency?.none)
                            ForEach(RepeatFrequency.allCases) { frequency in
                                Text(frequency.label).tag(RepeatFrequency?.some(frequency))
                            }
                        }
                    }
                } footer: {
                    if let repeatChoice, existing == nil {
                        Text("Penny will add this \(repeatChoice.label.lowercased()) starting \(DateText.long(date)). Manage it in Settings › Recurring.")
                    } else if existing?.ruleID != nil {
                        Text("This is part of a recurring series. Changes here affect only this one. Edit the series in Settings › Recurring.")
                    }
                }

                Section {
                    TextField("Anything you’d like to remember", text: $note, axis: .vertical)
                        .lineLimit(2...5)
                    if showErrors, let noteError {
                        Text(noteError).font(.footnote).foregroundStyle(Palette.red)
                    }
                } header: {
                    Text("Note (optional)")
                }

                if existing != nil {
                    Section {
                        Button("Delete transaction", role: .destructive) { confirmDelete = true }
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(existing == nil ? "Add transaction" : "Edit transaction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.fontWeight(.bold)
                }
            }
            .confirmationDialog("Delete this transaction?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete", role: .destructive) { deleteEntry() }
            } message: {
                Text("You can undo this right after.")
            }
            .onAppear(perform: loadExisting)
        }
        .lockGuard()
    }

    private var dateRange: ClosedRange<Date> {
        let calendar = Calendar.current
        let lower = calendar.date(from: DateComponents(year: 2000, month: 1, day: 1)) ?? .distantPast
        let upper = calendar.date(from: DateComponents(year: 2100, month: 12, day: 31)) ?? .distantFuture
        return lower...upper
    }

    private func categoryChip(_ option: LedgerCategory) -> some View {
        let selected = option == category
        return Button {
            category = option
        } label: {
            HStack(spacing: 6) {
                Image(systemName: option.symbol)
                Text(option.label).lineLimit(1).minimumScaleFactor(0.8)
            }
            .font(.subheadline.weight(selected ? .bold : .regular))
            .foregroundStyle(selected ? Palette.blue : Palette.ink)
            .frame(maxWidth: .infinity, minHeight: 44)
            .padding(.horizontal, 6)
            .background(selected ? Palette.paleBlue : Color.clear, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(selected ? Palette.blue : Palette.line, lineWidth: selected ? 2 : 1))
        }
        // Plain style stops a tap on one chip from triggering every button in the row.
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func loadExisting() {
        guard !loaded else { return }
        loaded = true
        if let entry = existing {
            kind = entry.kind
            amountText = Money.inputText(entry.amountCents)
            title = entry.title
            category = entry.kind == .income ? .groceries : entry.category
            date = entry.date
            note = entry.note
        } else {
            let calendar = Calendar.current
            date = calendar.isDate(state.selectedMonth, equalTo: Date(), toGranularity: .month)
                ? Date()
                : state.selectedMonth
        }
    }

    private func save() {
        guard isValid, let cents else {
            showErrors = true
            return
        }
        let cleanNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalCategory: LedgerCategory = kind == .income ? .income : category

        if let entry = existing {
            entry.title = trimmedTitle
            entry.amountCents = cents
            entry.kind = kind
            entry.category = finalCategory
            entry.date = date
            entry.note = cleanNote
            entry.isSample = false
            state.show("Changes saved.")
        } else {
            var ruleID: UUID?
            if let repeatChoice {
                let rule = RecurringRule(title: trimmedTitle, amountCents: cents, kind: kind,
                                         category: finalCategory, note: cleanNote,
                                         frequency: repeatChoice, startDate: date, generatedCount: 1)
                context.insert(rule)
                ruleID = rule.id
            }
            context.insert(LedgerEntry(title: trimmedTitle, amountCents: cents, kind: kind,
                                       category: finalCategory, date: date, note: cleanNote, ruleID: ruleID))
            state.show(repeatChoice == nil ? "Transaction added." : "Transaction added and set to repeat.")
        }
        try? context.save()
        state.goToMonth(of: date)
        dismiss()
    }

    private func deleteEntry() {
        guard let entry = existing else { return }
        EntryActions.delete(entry, context: context, state: state)
        dismiss()
    }
}

/// Shared delete-with-undo used by the form and the Activity list.
enum EntryActions {
    @MainActor
    static func delete(_ entry: LedgerEntry, context: ModelContext, state: AppState) {
        let title = entry.title
        let amount = entry.amountCents
        let kind = entry.kind
        let category = entry.category
        let date = entry.date
        let note = entry.note
        let ruleID = entry.ruleID
        context.delete(entry)
        try? context.save()
        state.show("“\(title)” deleted.") {
            context.insert(LedgerEntry(title: title, amountCents: amount, kind: kind, category: category,
                                       date: date, note: note, ruleID: ruleID))
            try? context.save()
        }
    }
}
