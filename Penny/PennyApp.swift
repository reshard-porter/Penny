import SwiftData
import SwiftUI

@main
struct PennyApp: App {
    @State private var appState = AppState.shared
    @State private var lock = AppLock(
        enabled: UserDefaults.standard.bool(forKey: "lockEnabled") && !LaunchOptions.isScreenshotMode)

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .environment(lock)
        }
        .modelContainer(PennyStore.container)
    }
}

struct RootView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Environment(AppState.self) private var state
    @Environment(AppLock.self) private var lock
    @Query private var rules: [RecurringRule]

    @AppStorage("lockEnabled") private var lockEnabled = false
    @AppStorage("hasOnboarded") private var hasOnboarded = false
    @AppStorage("didSeedSample") private var didSeedSample = false
    @AppStorage("appearance") private var appearanceRaw = AppearanceMode.system.rawValue
    @AppStorage("billReminders") private var billReminders = false
    @AppStorage("currency") private var currencyRaw = CurrencyCode.usd.rawValue

    @State private var showOnboarding = false
    @State private var didLaunch = false

    private var appearance: AppearanceMode { AppearanceMode(rawValue: appearanceRaw) ?? .system }

    var body: some View {
        @Bindable var state = state
        TabView(selection: $state.selectedTab) {
            NavigationStack { HomeView() }
                .tabItem { Label(AppTab.home.title, systemImage: AppTab.home.symbol) }
                .tag(AppTab.home)
            NavigationStack { ActivityView() }
                .tabItem { Label(AppTab.activity.title, systemImage: AppTab.activity.symbol) }
                .tag(AppTab.activity)
            NavigationStack { PlanView() }
                .tabItem { Label(AppTab.plan.title, systemImage: AppTab.plan.symbol) }
                .tag(AppTab.plan)
            NavigationStack { InsightsView() }
                .tabItem { Label(AppTab.insights.title, systemImage: AppTab.insights.symbol) }
                .tag(AppTab.insights)
            NavigationStack { SettingsView() }
                .tabItem { Label(AppTab.settings.title, systemImage: AppTab.settings.symbol) }
                .tag(AppTab.settings)
        }
        .tint(Palette.blue)
        .onChange(of: state.selectedTab) { _, _ in Haptics.selection() }
        .overlay(alignment: .bottom) {
            if let toast = state.toast {
                ToastView(toast: toast)
                    .padding(.bottom, 64)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: state.toast)
        .overlay {
            ConfettiView(trigger: state.celebration)
                .ignoresSafeArea()
        }
        .sheet(item: $state.editor) { target in
            EntryFormView(target: target)
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView { showOnboarding = false }
                .preferredColorScheme(appearance.colorScheme)
        }
        .preferredColorScheme(appearance.colorScheme)
        .lockGuard()
        .task {
            guard !didLaunch else { return }
            didLaunch = true
            launch()
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background:
                if lockEnabled { lock.isLocked = true }
            case .active:
                RecurringEngine.run(context: context)
                refreshBillReminders()
                if lockEnabled && lock.isLocked {
                    Task { await lock.unlock() }
                }
            default:
                break
            }
        }
    }

    private func launch() {
        if LaunchOptions.isScreenshotMode {
            if !SampleData.hasSamples(in: context) { SampleData.insert(into: context) }
            RecurringEngine.run(context: context)
            if LaunchOptions.forceOnboarding { showOnboarding = true }
            if LaunchOptions.opensEditor { state.editor = .add(.expense) }
            return
        }
        if !hasOnboarded {
            // People upgrading from Penny 2 already have data: skip the welcome tour.
            let existing = (try? context.fetchCount(FetchDescriptor<LedgerEntry>())) ?? 0
            if didSeedSample || existing > 0 {
                hasOnboarded = true
            } else {
                showOnboarding = true
            }
        }
        RecurringEngine.run(context: context)
        refreshBillReminders()
    }

    private func refreshBillReminders() {
        guard billReminders, !LaunchOptions.isScreenshotMode else { return }
        let currency = CurrencyCode(rawValue: currencyRaw) ?? .usd
        let bills = RecurringEngine.upcoming(rules: rules.filter { $0.kind == .expense }, days: 45)
            .map { item in
                Reminders.Bill(id: item.id, title: item.rule.title,
                               amount: Money.format(item.rule.amountCents, currency: currency), date: item.date)
            }
        Reminders.scheduleBills(bills)
    }
}
