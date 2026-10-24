import AppIntents
import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.openURL) private var openURL
    @Environment(AppState.self) private var state
    @Environment(AppLock.self) private var lock
    @Query private var entries: [LedgerEntry]
    @Query private var rules: [RecurringRule]
    @Query private var goals: [SavingsGoal]
    @AppStorage("currency") private var currencyRaw = CurrencyCode.usd.rawValue
    @AppStorage("lockEnabled") private var lockEnabled = false
    @AppStorage("appearance") private var appearanceRaw = AppearanceMode.system.rawValue
    @AppStorage("hapticsDisabled") private var hapticsDisabled = false
    @AppStorage("dailyReminder") private var dailyReminder = false
    @AppStorage("reminderMinutes") private var reminderMinutes = 20 * 60 + 30
    @AppStorage("billReminders") private var billReminders = false

    @State private var shareItem: ShareItem?
    @State private var confirmClear = false
    @State private var confirmRemoveSamples = false
    @State private var notificationsDenied = false
    @State private var currentIcon: String?
    @State private var showTour = false

    private var currency: CurrencyCode { CurrencyCode(rawValue: currencyRaw) ?? .usd }

    var body: some View {
        Form {
            Section {
                profileCard
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }

            Section {
                HStack(spacing: 8) {
                    ForEach(AppearanceMode.allCases) { mode in
                        appearanceButton(mode)
                    }
                }
                .padding(.vertical, 4)
                iconPicker
            } header: {
                Text("Appearance")
            }

            Section {
                Picker(selection: $currencyRaw) {
                    ForEach(CurrencyCode.allCases) { code in
                        Text("\(code.symbol.trimmingCharacters(in: .whitespaces))  \(code.name)").tag(code.rawValue)
                    }
                } label: {
                    settingLabel("Currency", symbol: "dollarsign.circle.fill", color: Palette.green)
                }
            } header: {
                Text("Money")
            } footer: {
                Text("Changes labels only. Existing amounts are not converted.")
            }

            Section {
                Toggle(isOn: lockBinding) {
                    settingLabel("Lock with \(AppLock.methodName)", symbol: AppLock.methodSymbol, color: Color(hex: 0x4F46E5))
                }
                .disabled(!AppLock.isAvailable && !lockEnabled)
            } header: {
                Text("Privacy")
            } footer: {
                if AppLock.isAvailable {
                    Text("Penny locks when you leave the app and hides your balances in the app switcher. Your data never leaves this iPhone.")
                } else {
                    Text("Set up Face ID, Touch ID or a passcode in the iPhone Settings app to use this.")
                }
            }

            Section {
                Toggle(isOn: dailyBinding) {
                    settingLabel("Daily check-in", symbol: "bell.badge.fill", color: Color(hex: 0xEA580C))
                }
                if dailyReminder {
                    DatePicker("Remind me at", selection: reminderTime, displayedComponents: .hourAndMinute)
                }
                Toggle(isOn: billBinding) {
                    settingLabel("Bill reminders", symbol: "calendar.badge.clock", color: Color(hex: 0x0891B2))
                }
            } header: {
                Text("Reminders")
            } footer: {
                if notificationsDenied {
                    Button("Notifications are off for Penny. Open Settings to allow them.") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                    }
                    .font(.footnote)
                } else {
                    Text("Bill reminders arrive at 9 AM the day before a recurring expense is due.")
                }
            }

            Section {
                NavigationLink {
                    RecurringListView()
                } label: {
                    LabeledContent {
                        Text("\(rules.filter(\.isActive).count) active")
                    } label: {
                        settingLabel("Recurring transactions", symbol: "repeat", color: Palette.blue)
                    }
                }
                SiriTipView(intent: LogExpenseIntent())
                    .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                ShortcutsLink()
                    .shortcutsLinkStyle(.automaticOutline)
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
            } header: {
                Text("Automation")
            } footer: {
                Text("Try “Hey Siri, log an expense in Penny” or “How much have I spent in Penny”.")
            }

            Section {
                Toggle(isOn: Binding(get: { !hapticsDisabled }, set: { hapticsDisabled = !$0 })) {
                    settingLabel("Haptic feedback", symbol: "hand.tap.fill", color: Color(hex: 0xDB2777))
                }
            }

            Section {
                Button {
                    export()
                } label: {
                    settingLabel("Export all as CSV", symbol: "square.and.arrow.up.fill", color: Palette.blue)
                }
                .disabled(entries.isEmpty)
                if entries.contains(where: { $0.isSample }) {
                    Button { confirmRemoveSamples = true } label: {
                        settingLabel("Clear sample data", symbol: "wand.and.stars", color: Color(hex: 0x7C3AED))
                    }
                }
                Button(role: .destructive) { confirmClear = true } label: {
                    settingLabel("Delete all transactions", symbol: "trash.fill", color: Palette.red)
                }
                .disabled(entries.isEmpty)
            } header: {
                Text("Your data")
            } footer: {
                Text("Everything is stored on this device. No account, no tracking.")
            }

            Section {
                Button { showTour = true } label: {
                    settingLabel("Replay the welcome tour", symbol: "sparkles", color: Palette.limeDeep)
                }
            } footer: {
                Text("Penny \(appVersion) · Small habits. Clearer money.")
                    .frame(maxWidth: .infinity)
                    .padding(.top, 12)
            }
        }
        .scrollContentBackground(.hidden)
        .pennyBackground()
        .navigationTitle("Settings")
        .task {
            currentIcon = AppIconOption.current
            notificationsDenied = await Reminders.isDenied()
        }
        .sheet(item: $shareItem) { item in
            ShareSheet(url: item.url).lockGuard().presentationDetents([.medium, .large])
        }
        .fullScreenCover(isPresented: $showTour) {
            OnboardingView(isReplay: true) { showTour = false }
        }
        .confirmationDialog("Delete all transactions?", isPresented: $confirmClear, titleVisibility: .visible) {
            Button("Delete \(entries.count) transactions", role: .destructive) { clearAll() }
        } message: {
            Text("Budgets, goals, recurring rules and settings are kept. Export a CSV first if you want a record. This can’t be undone.")
        }
        .confirmationDialog("Clear all sample data?", isPresented: $confirmRemoveSamples, titleVisibility: .visible) {
            Button("Clear sample data", role: .destructive) {
                SampleData.remove(from: context)
                state.show("Sample data cleared.", symbol: "sparkles")
            }
        } message: {
            Text("Sample transactions, goals and bills are removed. Anything you added yourself is kept.")
        }
    }

    // MARK: Pieces

    private var profileCard: some View {
        let months = Set(entries.map { DateText.monthKey($0.date) }).count
        return VStack(spacing: 16) {
            HStack(spacing: 14) {
                BrandMark(size: 60)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Penny").font(.title2.weight(.bold)).foregroundStyle(.white)
                    Text("Version \(appVersion)").font(.subheadline).foregroundStyle(Palette.heroText)
                }
                Spacer()
            }
            HStack(spacing: 0) {
                profileStat("\(entries.count)", "transactions")
                Spacer()
                profileStat("\(months)", months == 1 ? "month" : "months")
                Spacer()
                profileStat("\(goals.filter { !$0.isArchived }.count)", "goals")
            }
        }
        .heroCard(padding: 20, radius: 26)
    }

    private func profileStat(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(Typography.money(22, weight: .heavy)).foregroundStyle(.white)
            Text(label).font(.caption).foregroundStyle(Palette.heroText)
        }
    }

    private func settingLabel(_ title: String, symbol: String, color: Color) -> some View {
        Label {
            Text(title).foregroundStyle(Palette.ink)
        } icon: {
            SymbolBadge(symbol: symbol, color: color, size: 30)
        }
    }

    private func appearanceButton(_ mode: AppearanceMode) -> some View {
        let selected = appearanceRaw == mode.rawValue
        return Button {
            Haptics.selection()
            withAnimation { appearanceRaw = mode.rawValue }
        } label: {
            VStack(spacing: 6) {
                Image(systemName: mode.symbol).font(.title3)
                Text(mode.label).font(.caption.weight(.semibold))
            }
            .foregroundStyle(selected ? Palette.blue : Palette.muted)
            .frame(maxWidth: .infinity, minHeight: 64)
            .background(selected ? Palette.paleBlue : Palette.surfaceRaised,
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(selected ? Palette.blue : .clear, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var iconPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("App icon").font(.subheadline.weight(.semibold)).foregroundStyle(Palette.ink)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(AppIconOption.all) { option in
                        let selected = currentIcon == option.iconName
                        Button {
                            Haptics.selection()
                            AppIconOption.apply(option) { success in
                                if success { currentIcon = option.iconName }
                            }
                        } label: {
                            VStack(spacing: 6) {
                                Image(option.preview)
                                    .resizable()
                                    .frame(width: 62, height: 62)
                                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .strokeBorder(Palette.line, lineWidth: 0.5))
                                    .padding(3)
                                    .overlay(RoundedRectangle(cornerRadius: 17, style: .continuous)
                                        .strokeBorder(selected ? Palette.blue : .clear, lineWidth: 2.5))
                                Text(option.label)
                                    .font(.caption.weight(selected ? .bold : .regular))
                                    .foregroundStyle(selected ? Palette.blue : Palette.muted)
                            }
                        }
                        .buttonStyle(PressableStyle(scale: 0.94))
                        .accessibilityLabel("\(option.label) icon")
                        .accessibilityAddTraits(selected ? .isSelected : [])
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: Bindings

    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "3.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(version) (\(build))"
    }

    private var lockBinding: Binding<Bool> {
        Binding(
            get: { lockEnabled },
            set: { wantsLock in
                if wantsLock {
                    Task { @MainActor in
                        if await lock.verify(reason: "Confirm it’s you to turn on the Penny lock.") {
                            lockEnabled = true
                            lock.isLocked = false
                            Haptics.success()
                        }
                    }
                } else {
                    lockEnabled = false
                    lock.isLocked = false
                }
            })
    }

    private var dailyBinding: Binding<Bool> {
        Binding(
            get: { dailyReminder },
            set: { wantsReminder in
                if wantsReminder {
                    Task { @MainActor in
                        if await Reminders.requestAuthorization() {
                            dailyReminder = true
                            Reminders.scheduleDaily(minutes: reminderMinutes)
                            notificationsDenied = false
                        } else {
                            notificationsDenied = true
                        }
                    }
                } else {
                    dailyReminder = false
                    Reminders.cancelDaily()
                }
            })
    }

    private var billBinding: Binding<Bool> {
        Binding(
            get: { billReminders },
            set: { wantsReminders in
                if wantsReminders {
                    Task { @MainActor in
                        if await Reminders.requestAuthorization() {
                            billReminders = true
                            notificationsDenied = false
                            scheduleBills()
                        } else {
                            notificationsDenied = true
                        }
                    }
                } else {
                    billReminders = false
                    Reminders.cancelBills()
                }
            })
    }

    private var reminderTime: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(bySettingHour: reminderMinutes / 60, minute: reminderMinutes % 60,
                                      second: 0, of: Date()) ?? Date()
            },
            set: { date in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
                reminderMinutes = (parts.hour ?? 20) * 60 + (parts.minute ?? 30)
                Reminders.scheduleDaily(minutes: reminderMinutes)
            })
    }

    // MARK: Actions

    private func scheduleBills() {
        let bills = RecurringEngine.upcoming(rules: rules.filter { $0.kind == .expense }, days: 45).map { item in
            Reminders.Bill(id: item.id, title: item.rule.title,
                           amount: Money.format(item.rule.amountCents, currency: currency), date: item.date)
        }
        Reminders.scheduleBills(bills)
    }

    private func export() {
        if let url = CSVExport.file(entries: entries, currency: currency, name: "Penny-all-transactions.csv") {
            shareItem = ShareItem(url: url)
        } else {
            state.show("Couldn’t create the CSV file. Please try again.", symbol: "exclamationmark.triangle.fill")
        }
    }

    private func clearAll() {
        for entry in entries { context.delete(entry) }
        try? context.save()
        state.show("All transactions deleted. Budgets and goals are unchanged.", symbol: "trash.fill")
    }
}
