import SwiftUI
import UIKit

// MARK: - Month switcher

struct MonthSwitcher: View {
    @Environment(AppState.self) private var state

    private var isCurrentMonth: Bool {
        Calendar.current.isDate(state.selectedMonth, equalTo: Date(), toGranularity: .month)
    }

    var body: some View {
        HStack(spacing: 4) {
            Button {
                state.selectedMonth = Calendar.current.month(offset: -1, from: state.selectedMonth)
            } label: {
                Image(systemName: "chevron.left").frame(width: 44, height: 44)
            }
            .accessibilityLabel("Previous month")

            Spacer(minLength: 0)
            VStack(spacing: 2) {
                Text(DateText.month(state.selectedMonth))
                    .font(.headline)
                    .foregroundStyle(Palette.ink)
                if !isCurrentMonth {
                    Button("Back to this month") { state.goToMonth(of: Date()) }
                        .font(.caption.weight(.semibold))
                }
            }
            Spacer(minLength: 0)

            Button {
                state.selectedMonth = Calendar.current.month(offset: 1, from: state.selectedMonth)
            } label: {
                Image(systemName: "chevron.right").frame(width: 44, height: 44)
            }
            .accessibilityLabel("Next month")
        }
        .padding(.horizontal, 4)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Palette.line))
    }
}

// MARK: - Entries

struct CategoryBadge: View {
    let category: LedgerCategory
    var size: CGFloat = 42

    var body: some View {
        Image(systemName: category.symbol)
            .font(.system(size: size * 0.42, weight: .semibold))
            .foregroundStyle(category.color)
            .frame(width: size, height: size)
            .background(category.color.opacity(0.12), in: RoundedRectangle(cornerRadius: size * 0.3, style: .continuous))
            .accessibilityHidden(true)
    }
}

struct EntryRow: View {
    let entry: LedgerEntry
    let currency: CurrencyCode

    var body: some View {
        let isIncome = entry.kind == .income
        HStack(spacing: 12) {
            CategoryBadge(category: entry.category)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Text(entry.title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Palette.ink)
                        .lineLimit(1)
                    if entry.ruleID != nil {
                        Image(systemName: "repeat")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(Palette.muted)
                            .accessibilityLabel("Recurring")
                    }
                }
                Text("\(entry.category.label) · \(DateText.short(entry.date))")
                    .font(.footnote)
                    .foregroundStyle(Palette.muted)
            }
            Spacer(minLength: 8)
            Text((isIncome ? "+" : "−") + Money.format(entry.amountCents, currency: currency))
                .font(.body.weight(.bold).monospacedDigit())
                .foregroundStyle(isIncome ? Palette.green : Palette.ink)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(entry.title), \(isIncome ? "income" : "expense"), \(Money.format(entry.amountCents, currency: currency)), \(DateText.long(entry.date)), \(entry.category.label)")
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Small building blocks

struct ProgressBar: View {
    let value: Double
    var tint: Color = Palette.blue
    var track: Color = Palette.line
    var height: CGFloat = 8

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(track)
                Capsule()
                    .fill(tint)
                    .frame(width: max(value > 0 ? height : 0, geometry.size.width * min(max(value, 0), 1)))
            }
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }
}

struct SectionTitle: View {
    let title: String
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.title3.weight(.bold)).foregroundStyle(Palette.ink)
            if let subtitle {
                Text(subtitle).font(.footnote).foregroundStyle(Palette.muted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct StatTile: View {
    let label: String
    let value: String
    let symbol: String
    var tint: Color = Palette.blue

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: symbol)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 32, height: 32)
                .background(tint.opacity(0.1), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            Text(label).font(.footnote).foregroundStyle(Palette.muted)
            Text(value)
                .font(.headline.monospacedDigit())
                .foregroundStyle(Palette.ink)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
        }
        .card(padding: 14)
        .accessibilityElement(children: .combine)
    }
}

struct SampleBanner: View {
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles").foregroundStyle(Palette.blue)
            Text("Sample data · Explore freely, then make it yours.")
                .font(.footnote)
                .foregroundStyle(Palette.ink)
            Spacer(minLength: 4)
            Button("Remove", action: onRemove)
                .font(.footnote.weight(.bold))
        }
        .padding(12)
        .background(Palette.paleBlue, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

// MARK: - Toast with undo

struct ToastView: View {
    @Environment(AppState.self) private var state
    let toast: Toast

    var body: some View {
        HStack(spacing: 12) {
            Text(toast.message)
                .font(.subheadline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let undo = toast.undo {
                Button("Undo") {
                    undo()
                    state.toast = nil
                }
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Palette.lime)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Palette.navy, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(0.2), radius: 12, y: 4)
        .padding(.horizontal)
        .task(id: toast.id) {
            try? await Task.sleep(for: .seconds(6))
            if state.toast?.id == toast.id { state.toast = nil }
        }
        .accessibilityElement(children: .contain)
    }
}

// MARK: - Lock screens

struct LockView: View {
    @Environment(AppLock.self) private var lock

    var body: some View {
        ZStack {
            Palette.navy.ignoresSafeArea()
            VStack(spacing: 18) {
                BrandMark(size: 64)
                Text("Penny is locked")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
                if let message = lock.message {
                    Text(message).font(.footnote).foregroundStyle(Palette.heroText)
                }
                Button {
                    Task { await lock.unlock() }
                } label: {
                    Label("Unlock with \(AppLock.methodName)", systemImage: AppLock.methodSymbol)
                        .font(.headline)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 14)
                        .background(Palette.lime, in: Capsule())
                        .foregroundStyle(Palette.navy)
                }
                .disabled(lock.isAuthenticating)
            }
            .padding()
        }
        .task { await lock.unlock() }
    }
}

/// Covers a screen with the lock (or the privacy cover in the app switcher).
/// Applied to the root view and to every sheet, since sheets sit above the root.
struct LockGuard: ViewModifier {
    @Environment(AppLock.self) private var lock
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("lockEnabled") private var lockEnabled = false

    func body(content: Content) -> some View {
        content.overlay {
            if lockEnabled && lock.isLocked {
                LockView()
            } else if lockEnabled && scenePhase != .active {
                PrivacyCover()
            }
        }
    }
}

extension View {
    func lockGuard() -> some View { modifier(LockGuard()) }
}

/// Hides balances in the app switcher when the lock is on.
struct PrivacyCover: View {
    var body: some View {
        ZStack {
            Palette.navy.ignoresSafeArea()
            BrandMark(size: 64)
        }
    }
}

struct BrandMark: View {
    var size: CGFloat = 40

    var body: some View {
        Image(systemName: "chart.bar.fill")
            .font(.system(size: size * 0.5, weight: .bold))
            .foregroundStyle(Palette.navy)
            .frame(width: size, height: size)
            .background(Palette.lime, in: RoundedRectangle(cornerRadius: size * 0.3, style: .continuous))
            .accessibilityHidden(true)
    }
}

// MARK: - Share sheet

struct ShareSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
