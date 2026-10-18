import Foundation
import Observation

/// Shared, screen-independent state: the month being viewed and the undo toast.
@Observable
final class AppState {
    var selectedMonth: Date = Calendar.current.startOfMonth(for: Date())
    var toast: Toast?

    func show(_ message: String, undo: (() -> Void)? = nil) {
        toast = Toast(message: message, undo: undo)
    }

    func goToMonth(of date: Date) {
        selectedMonth = Calendar.current.startOfMonth(for: date)
    }
}

struct Toast: Identifiable, Equatable {
    let id = UUID()
    let message: String
    let undo: (() -> Void)?

    static func == (lhs: Toast, rhs: Toast) -> Bool { lhs.id == rhs.id }
}

/// What the add/edit sheet should show.
enum EditorTarget: Identifiable {
    case new
    case edit(LedgerEntry)

    var id: String {
        switch self {
        case .new: return "new"
        case .edit(let entry): return entry.id.uuidString
        }
    }
}

/// Wraps a file URL so it can drive `.sheet(item:)`.
struct ShareItem: Identifiable {
    let id = UUID()
    let url: URL
}
