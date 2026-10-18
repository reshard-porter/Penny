import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var state
    @Environment(AppLock.self) private var lock
    @Query private var entries: [LedgerEntry]
    @Query private var rules: [RecurringRule]
    @AppStorage("currency") private var currencyRaw = CurrencyCode.usd.rawValue
    @AppStorage("lockEnabled") private var lockEnabled = false

    @State private var shareItem: ShareItem?
    @State private var confirmClear = false
    @State private var confirmRemoveSamples = false

    private var currency: CurrencyCode { CurrencyCode(rawValue: currencyRaw) ?? .usd }

    private var lockBinding: Binding<Bool> {
        Binding(
            get: { lockEnabled },
            set: { wantsLock in
                if wantsLock {
                    Task { @MainActor in
                        if await lock.verify(reason: "Confirm it’s you to turn on the Penny lock.") {
                            lockEnabled = true
                            lock.isLocked = false
                        }
                    }
                } else {
                    lockEnabled = false
                    lock.isLocked = false
                }
            })
    }

    var body: some View {
        Form {
            Section {
                Picker("Display currency", selection: $currencyRaw) {
                    ForEach(CurrencyCode.allCases) { code in
                        Text("\(code.rawValue) · \(code.name)").tag(code.rawValue)
                    }
                }
            } header: {
                Text("Display")
            } footer: {
                Text("Changes labels only. Existing amounts are not converted.")
            }

            Section {
                Toggle(isOn: lockBinding) {
                    Label("Lock with \(AppLock.methodName)", systemImage: AppLock.methodSymbol)
                }
                .disabled(!AppLock.isAvailable && !lockEnabled)
            } header: {
                Text("Privacy")
            } footer: {
                if AppLock.isAvailable {
                    Text("Penny locks when you leave the app and hides your balances in the app switcher.")
                } else {
                    Text("Set up Face ID, Touch ID or a passcode in the iPhone Settings app to use this.")
                }
            }

            Section("Automation") {
                NavigationLink {
                    RecurringListView()
                } label: {
                    LabeledContent {
                        Text("\(rules.filter(\.isActive).count) active")
                    } label: {
                        Label("Recurring transactions", systemImage: "repeat")
                    }
                }
            }

            Section {
                LabeledContent("Transactions on this device", value: "\(entries.count)")
                Button {
                    export()
                } label: {
                    Label("Export all as CSV", systemImage: "square.and.arrow.up")
                }
                .disabled(entries.isEmpty)
                if entries.contains(where: { $0.isSample }) {
                    Button("Remove sample data", systemImage: "sparkles") { confirmRemoveSamples = true }
                }
                Button("Clear all transactions", systemImage: "trash", role: .destructive) { confirmClear = true }
                    .disabled(entries.isEmpty)
            } header: {
                Text("Your data")
            } footer: {
                Text("Everything stays on this device. No account required.")
            }

            Section {
                HStack(spacing: 12) {
                    BrandMark(size: 40)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Penny 2.0").font(.headline)
                        Text("Small habits. Clearer money.").font(.footnote).foregroundStyle(Palette.muted)
                    }
                }
            }
        }
        .navigationTitle("Settings")
        .sheet(item: $shareItem) { item in ShareSheet(url: item.url).lockGuard().presentationDetents([.medium, .large]) }
        .confirmationDialog("Clear all transactions?", isPresented: $confirmClear, titleVisibility: .visible) {
            Button("Clear \(entries.count) transactions", role: .destructive) { clearAll() }
        } message: {
            Text("Budgets, recurring rules and your currency are kept. Export a CSV first if you want a record. This can’t be undone.")
        }
        .confirmationDialog("Remove all sample data?", isPresented: $confirmRemoveSamples, titleVisibility: .visible) {
            Button("Remove sample data", role: .destructive) {
                for entry in entries where entry.isSample { context.delete(entry) }
                try? context.save()
                state.show("Sample data removed.")
            }
        } message: {
            Text("Transactions you added yourself are kept.")
        }
    }

    private func export() {
        if let url = CSVExport.file(entries: entries, currency: currency, name: "Penny-all-transactions.csv") {
            shareItem = ShareItem(url: url)
        } else {
            state.show("Couldn’t create the CSV file. Please try again.")
        }
    }

    private func clearAll() {
        for entry in entries { context.delete(entry) }
        try? context.save()
        state.show("Your fresh start is ready. Budgets are unchanged.")
    }
}
