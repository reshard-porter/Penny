import SwiftData
import SwiftUI

@main
struct PennyApp: App {
    @State private var appState = AppState()
    @State private var lock = AppLock(enabled: UserDefaults.standard.bool(forKey: "lockEnabled"))

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .environment(lock)
        }
        .modelContainer(for: [LedgerEntry.self, BudgetLimit.self, RecurringRule.self])
    }
}

struct RootView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Environment(AppState.self) private var state
    @Environment(AppLock.self) private var lock
    @AppStorage("lockEnabled") private var lockEnabled = false
    @AppStorage("didSeedSample") private var didSeedSample = false
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack { OverviewView(selectedTab: $selectedTab) }
                .tabItem { Label("Overview", systemImage: "square.grid.2x2") }
                .tag(0)
            NavigationStack { ActivityView() }
                .tabItem { Label("Activity", systemImage: "list.bullet.rectangle") }
                .tag(1)
            NavigationStack { BudgetsView() }
                .tabItem { Label("Budgets", systemImage: "chart.pie") }
                .tag(2)
            NavigationStack { InsightsView() }
                .tabItem { Label("Insights", systemImage: "chart.xyaxis.line") }
                .tag(3)
            NavigationStack { SettingsView() }
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(4)
        }
        .tint(Palette.blue)
        .overlay(alignment: .bottom) {
            if let toast = state.toast {
                ToastView(toast: toast)
                    .padding(.bottom, 60)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.snappy, value: state.toast)
        .lockGuard()
        .task {
            seedSampleDataIfNeeded()
            RecurringEngine.run(context: context)
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background:
                if lockEnabled { lock.isLocked = true }
            case .active:
                RecurringEngine.run(context: context)
                if lockEnabled && lock.isLocked {
                    Task { await lock.unlock() }
                }
            default:
                break
            }
        }
    }

    private func seedSampleDataIfNeeded() {
        guard !didSeedSample else { return }
        didSeedSample = true
        let existing = (try? context.fetchCount(FetchDescriptor<LedgerEntry>())) ?? 0
        if existing == 0 { SampleData.insert(into: context) }
    }
}
