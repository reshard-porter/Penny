import PhotosUI
import SwiftData
import SwiftUI

/// Add, edit or duplicate a transaction. New transactions can be set to repeat.
struct EntryFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var state
    @Query(sort: \LedgerEntry.date, order: .reverse) private var history: [LedgerEntry]
    @AppStorage("currency") private var currencyRaw = CurrencyCode.usd.rawValue

    let target: EditorTarget

    private enum Field { case amount, title, note }

    @State private var kind: EntryKind = .expense
    @State private var amountText = ""
    @State private var title = ""
    @State private var category: LedgerCategory = .groceries
    @State private var date = Date()
    @State private var note = ""
    @State private var repeatChoice: RepeatFrequency?
    @State private var receipt: Data?
    @State private var photoItem: PhotosPickerItem?
    @State private var showCamera = false
    @State private var showReceipt = false
    @State private var showErrors = false
    @State private var confirmDelete = false
    @State private var loaded = false
    @FocusState private var focus: Field?

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
    private var accent: Color { kind == .income ? Palette.green : Palette.blue }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    PillPicker(options: [(EntryKind.expense, "Expense"), (EntryKind.income, "Income")], selection: $kind)
                        .padding(.top, 4)
                    amountSection
                    titleSection
                    categorySection
                    detailsSection
                    receiptSection
                    if existing != nil {
                        Button(role: .destructive) { confirmDelete = true } label: {
                            Label("Delete transaction", systemImage: "trash")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity, minHeight: 48)
                        }
                        .buttonStyle(.bordered)
                        .tint(Palette.red)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
            .pennyBackground()
            .safeAreaInset(edge: .bottom) {
                Button(action: save) {
                    Label(saveTitle, systemImage: "checkmark")
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 8)
                .background(.bar)
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { focus = nil }.fontWeight(.semibold)
                }
            }
            .confirmationDialog("Delete this transaction?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete", role: .destructive) { deleteEntry() }
            } message: {
                Text("You can undo this right after.")
            }
            .onAppear(perform: load)
            .onChange(of: kind) { _, newKind in
                if !LedgerCategory.cases(for: newKind).contains(category) {
                    category = LedgerCategory.cases(for: newKind).first ?? .other
                }
            }
            .onChange(of: photoItem) { _, item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let compressed = ReceiptImage.compressed(data) {
                        withAnimation { receipt = compressed }
                    }
                    photoItem = nil
                }
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraPicker { image in
                    if let image, let data = ReceiptImage.compressed(image) {
                        withAnimation { receipt = data }
                    }
                }
                .ignoresSafeArea()
            }
            .sheet(isPresented: $showReceipt) {
                if let receipt { ReceiptViewer(data: receipt) }
            }
        }
        .lockGuard()
    }

    private var navigationTitle: String {
        switch target {
        case .add(let kind): return kind == .income ? "New income" : "New expense"
        case .edit: return "Edit transaction"
        case .duplicate: return "Duplicate"
        }
    }

    private var saveTitle: String {
        existing == nil ? (kind == .income ? "Add income" : "Add expense") : "Save changes"
    }

    // MARK: Sections

    private var amountSection: some View {
        VStack(spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(kind == .income ? "+" : "−")
                    .font(Typography.money(34, weight: .bold))
                    .foregroundStyle(accent.opacity(0.7))
                Text(currency.symbol)
                    .font(Typography.money(34, weight: .bold))
                    .foregroundStyle(Palette.muted)
                TextField("0.00", text: $amountText)
                    .keyboardType(.decimalPad)
                    .font(Typography.money(56, weight: .heavy))
                    .foregroundStyle(Palette.ink)
                    .fixedSize()
                    .focused($focus, equals: .amount)
                    .accessibilityLabel("Amount")
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .onTapGesture { focus = .amount }
            if showErrors, let amountError {
                Text(amountError).font(.footnote).foregroundStyle(Palette.red)
            }
        }
        .padding(.vertical, 22)
        .card()
    }

    private var suggestions: [LedgerEntry] {
        var seen = Set<String>()
        var result: [LedgerEntry] = []
        let query = trimmedTitle.lowercased()
        for entry in history where entry.kind == kind {
            let key = entry.title.lowercased()
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            if query.isEmpty || (key.contains(query) && key != query) { result.append(entry) }
            if result.count == 6 { break }
        }
        return result
    }

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(kind == .income ? "Where did it come from?" : "What was it for?")
                .font(.footnote.weight(.semibold)).foregroundStyle(Palette.muted)
            TextField(kind == .income ? "e.g. Monthly salary" : "e.g. Weekly groceries", text: $title)
                .font(.body.weight(.medium))
                .textInputAutocapitalization(.sentences)
                .focused($focus, equals: .title)
                .submitLabel(.done)
                .padding(14)
                .background(Palette.surfaceRaised, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            if showErrors, let titleError {
                Text(titleError).font(.footnote).foregroundStyle(Palette.red)
            }
            let options = suggestions
            if !options.isEmpty && existing == nil {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(options) { option in
                            Button { apply(option) } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: option.category.symbol)
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(option.category.color)
                                    Text(option.title).font(.subheadline.weight(.medium)).lineLimit(1)
                                    Text(Money.short(option.amountCents, currency: currency))
                                        .font(.caption.monospacedDigit()).foregroundStyle(Palette.muted)
                                }
                                .foregroundStyle(Palette.ink)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Palette.surfaceRaised, in: Capsule())
                            }
                            .buttonStyle(PressableStyle(scale: 0.95))
                        }
                    }
                }
                .scrollClipDisabled()
            }
        }
        .card()
    }

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Category").font(.footnote.weight(.semibold)).foregroundStyle(Palette.muted)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 4), spacing: 14) {
                ForEach(LedgerCategory.cases(for: kind)) { option in
                    categoryCell(option)
                }
            }
        }
        .card()
    }

    private func categoryCell(_ option: LedgerCategory) -> some View {
        let selected = option == category
        return Button {
            Haptics.selection()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { category = option }
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    if selected {
                        SymbolBadge(symbol: option.symbol, color: option.color, size: 50)
                    } else {
                        Image(systemName: option.symbol)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(option.color)
                            .frame(width: 50, height: 50)
                            .background(option.color.opacity(0.12),
                                        in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }
                .scaleEffect(selected ? 1.06 : 1)
                Text(option.label)
                    .font(.caption2.weight(selected ? .bold : .medium))
                    .foregroundStyle(selected ? Palette.ink : Palette.muted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(option.label)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var detailsSection: some View {
        let calendar = Calendar.current
        let yesterday = calendar.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Chip(title: "Today", isSelected: calendar.isDateInToday(date)) { date = Date() }
                Chip(title: "Yesterday", isSelected: calendar.isDateInYesterday(date)) { date = yesterday }
                Spacer(minLength: 4)
                DatePicker("Date", selection: $date, in: dateRange, displayedComponents: .date)
                    .labelsHidden()
            }
            if existing == nil {
                Divider()
                HStack {
                    Label("Repeat", systemImage: "repeat").foregroundStyle(Palette.ink)
                    Spacer()
                    Picker("Repeat", selection: $repeatChoice) {
                        Text("Never").tag(RepeatFrequency?.none)
                        ForEach(RepeatFrequency.allCases) { frequency in
                            Text(frequency.label).tag(RepeatFrequency?.some(frequency))
                        }
                    }
                    .labelsHidden()
                }
                if let repeatChoice {
                    Text("Penny will add this \(repeatChoice.label.lowercased()) from \(DateText.long(date)). Manage it in Settings › Recurring.")
                        .font(.caption).foregroundStyle(Palette.muted)
                }
            } else if existing?.ruleID != nil {
                Text("Part of a recurring series. Changes here affect only this one.")
                    .font(.caption).foregroundStyle(Palette.muted)
            }
            Divider()
            TextField("Add a note", text: $note, axis: .vertical)
                .lineLimit(1...4)
                .focused($focus, equals: .note)
            if showErrors, let noteError {
                Text(noteError).font(.footnote).foregroundStyle(Palette.red)
            }
        }
        .card()
    }

    private var receiptSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Receipt").font(.footnote.weight(.semibold)).foregroundStyle(Palette.muted)
            if let receipt, let image = UIImage(data: receipt) {
                HStack(spacing: 14) {
                    Button { showReceipt = true } label: {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 72, height: 92)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Palette.line))
                    }
                    .accessibilityLabel("View receipt")
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Receipt attached").font(.subheadline.weight(.semibold)).foregroundStyle(Palette.ink)
                        Button("Remove", role: .destructive) {
                            withAnimation { self.receipt = nil }
                        }
                        .font(.subheadline.weight(.semibold))
                    }
                    Spacer()
                }
            } else {
                HStack(spacing: 10) {
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        receiptButtonLabel("Photo library", symbol: "photo.on.rectangle")
                    }
                    if UIImagePickerController.isSourceTypeAvailable(.camera) {
                        Button { showCamera = true } label: {
                            receiptButtonLabel("Take photo", symbol: "camera.fill")
                        }
                    }
                }
            }
        }
        .card()
    }

    private func receiptButtonLabel(_ title: String, symbol: String) -> some View {
        Label(title, systemImage: symbol)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Palette.blue)
            .frame(maxWidth: .infinity, minHeight: 46)
            .background(Palette.paleBlue, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var dateRange: ClosedRange<Date> {
        let calendar = Calendar.current
        let lower = calendar.date(from: DateComponents(year: 2000, month: 1, day: 1)) ?? .distantPast
        let upper = calendar.date(from: DateComponents(year: 2100, month: 12, day: 31)) ?? .distantFuture
        return lower...upper
    }

    // MARK: Actions

    private func apply(_ suggestion: LedgerEntry) {
        Haptics.selection()
        title = suggestion.title
        category = LedgerCategory.normalized(suggestion.category, for: kind)
        if amountText.isEmpty { amountText = Money.inputText(suggestion.amountCents) }
        focus = nil
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        switch target {
        case .edit(let entry), .duplicate(let entry):
            kind = entry.kind
            amountText = Money.inputText(entry.amountCents)
            title = entry.title
            category = entry.category
            note = entry.note
            if case .edit = target {
                date = entry.date
                receipt = entry.receiptData
            } else {
                date = Date()
            }
        case .add(let newKind):
            kind = newKind
            category = newKind == .income ? .income : .groceries
            let calendar = Calendar.current
            date = calendar.isDate(state.selectedMonth, equalTo: Date(), toGranularity: .month)
                ? Date()
                : calendar.date(bySettingHour: 12, minute: 0, second: 0, of: state.selectedMonth) ?? state.selectedMonth
            if LaunchOptions.isScreenshotMode {
                amountText = "42.50"
                title = "Fresh Market"
                note = "Weekly shop"
            } else {
                focus = .amount
            }
        }
    }

    private func save() {
        guard isValid, let cents else {
            showErrors = true
            Haptics.warning()
            return
        }
        let cleanNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalCategory = LedgerCategory.normalized(category, for: kind)

        if let entry = existing {
            entry.title = trimmedTitle
            entry.amountCents = cents
            entry.kind = kind
            entry.category = finalCategory
            entry.date = date
            entry.note = cleanNote
            entry.isSample = false
            if entry.receiptData != receipt { entry.setReceipt(receipt) }
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
                                       category: finalCategory, date: date, note: cleanNote, ruleID: ruleID,
                                       receiptData: receipt))
            let what = kind == .income ? "Income" : "Expense"
            state.show(repeatChoice == nil ? "\(what) added." : "\(what) added and set to repeat.")
        }
        try? context.save()
        Haptics.success()
        state.goToMonth(of: date)
        dismiss()
    }

    private func deleteEntry() {
        guard let entry = existing else { return }
        EntryActions.delete(entry, context: context, state: state)
        dismiss()
    }
}
