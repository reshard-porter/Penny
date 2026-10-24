import Foundation
import Observation
import SwiftData

/// Shared, screen-independent state: selected tab and month, the add/edit sheet and the undo toast.
/// A single shared instance so Siri / Shortcuts can open the add sheet too.
@MainActor
@Observable
final class AppState {
    static let shared = AppState()

    var selectedTab: AppTab = .home
    var selectedMonth: Date = Calendar.current.startOfMonth(for: Date())
    var planSegment: PlanSegment = .budgets
    var editor: EditorTarget?
    var toast: Toast?
    /// Bumped to trigger a celebration (confetti) anywhere in the app.
    var celebration = 0

    init() {
        if let raw = LaunchOptions.string("PennyStartTab"), let value = Int(raw), let tab = AppTab(rawValue: value) {
            selectedTab = tab
        }
        if LaunchOptions.string("PennyPlanSegment") == "goals" { planSegment = .goals }
    }

    func show(_ message: String, symbol: String = "checkmark.circle.fill", undo: (() -> Void)? = nil) {
        toast = Toast(message: message, symbol: symbol, undo: undo)
    }

    func goToMonth(of date: Date) {
        selectedMonth = Calendar.current.startOfMonth(for: date)
    }

    func add(_ kind: EntryKind = .expense) {
        Haptics.tap()
        editor = .add(kind)
    }

    func celebrate() {
        Haptics.success()
        celebration += 1
    }
}

enum AppTab: Int, CaseIterable, Identifiable {
    case home, activity, plan, insights, settings

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .home: return "Home"
        case .activity: return "Activity"
        case .plan: return "Plan"
        case .insights: return "Insights"
        case .settings: return "Settings"
        }
    }

    var symbol: String {
        switch self {
        case .home: return "house.fill"
        case .activity: return "list.bullet.rectangle.portrait.fill"
        case .plan: return "target"
        case .insights: return "chart.xyaxis.line"
        case .settings: return "gearshape.fill"
        }
    }
}

enum PlanSegment: String, CaseIterable, Identifiable {
    case budgets, goals

    var id: String { rawValue }
    var label: String { self == .budgets ? "Budgets" : "Goals" }
}

struct Toast: Identifiable, Equatable {
    let id = UUID()
    let message: String
    let symbol: String
    let undo: (() -> Void)?

    static func == (lhs: Toast, rhs: Toast) -> Bool { lhs.id == rhs.id }
}

/// What the add/edit sheet should show.
enum EditorTarget: Identifiable {
    case add(EntryKind)
    case edit(LedgerEntry)
    case duplicate(LedgerEntry)

    var id: String {
        switch self {
        case .add(let kind): return "add-\(kind.rawValue)"
        case .edit(let entry): return "edit-\(entry.id.uuidString)"
        case .duplicate(let entry): return "duplicate-\(entry.id.uuidString)"
        }
    }
}

/// Wraps a file URL so it can drive `.sheet(item:)`.
struct ShareItem: Identifiable {
    let id = UUID()
    let url: URL
}

// MARK: - Launch options

/// Launch arguments used by the screenshot script (e.g. `-PennyScreenshotMode YES`).
enum LaunchOptions {
    static func string(_ key: String) -> String? {
        UserDefaults.standard.volatileDomain(forName: UserDefaults.argumentDomain)[key] as? String
    }

    static var isScreenshotMode: Bool { string("PennyScreenshotMode") == "YES" }
    static var forceOnboarding: Bool { string("PennyShowOnboarding") == "YES" }
    static var opensEditor: Bool { string("PennyOpenEditor") == "YES" }
    /// "more" or "end": where long screens scroll to for screenshots.
    static var scrollTarget: String? { string("PennyScroll") }
}

// MARK: - Store

enum PennyStore {
    static let schema = Schema([
        LedgerEntry.self, BudgetLimit.self, RecurringRule.self, SavingsGoal.self, GoalContribution.self,
    ])

    /// One container for the app and its Siri / Shortcuts actions.
    /// Screenshot mode uses a throwaway in-memory store so real data is never touched.
    static let container: ModelContainer = {
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: LaunchOptions.isScreenshotMode)
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            // Never crash on launch: fall back to a temporary store and keep the error visible in logs.
            print("Penny: could not open the data store: \(error)")
            let fallback = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            // swiftlint:disable:next force_try
            return try! ModelContainer(for: schema, configurations: [fallback])
        }
    }()
}
