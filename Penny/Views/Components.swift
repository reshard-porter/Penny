import SwiftUI
import UIKit

// MARK: - Month switcher

struct MonthSwitcher: View {
    @Environment(AppState.self) private var state

    private var isCurrentMonth: Bool {
        Calendar.current.isDate(state.selectedMonth, equalTo: Date(), toGranularity: .month)
    }

    var body: some View {
        HStack(spacing: 2) {
            arrow("chevron.left", label: "Previous month", offset: -1)
            Spacer(minLength: 0)
            VStack(spacing: 1) {
                Text(DateText.month(state.selectedMonth))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Palette.ink)
                    .contentTransition(.numericText())
                if !isCurrentMonth {
                    Button("Jump to today") {
                        Haptics.selection()
                        withAnimation(.snappy) { state.goToMonth(of: Date()) }
                    }
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Palette.blue)
                }
            }
            Spacer(minLength: 0)
            arrow("chevron.right", label: "Next month", offset: 1)
        }
        .padding(4)
        .frame(minHeight: 50)
        .background(Palette.surface, in: Capsule())
        .overlay(Capsule().strokeBorder(Palette.line, lineWidth: 0.5))
    }

    private func arrow(_ symbol: String, label: String, offset: Int) -> some View {
        Button {
            Haptics.selection()
            withAnimation(.snappy) {
                state.selectedMonth = Calendar.current.month(offset: offset, from: state.selectedMonth)
            }
        } label: {
            Image(systemName: symbol)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Palette.ink)
                .frame(width: 42, height: 42)
                .background(Palette.surfaceRaised, in: Circle())
        }
        .buttonStyle(PressableStyle(scale: 0.9))
        .accessibilityLabel(label)
    }
}

// MARK: - Badges

struct CategoryBadge: View {
    let category: LedgerCategory
    var size: CGFloat = 44

    var body: some View {
        SymbolBadge(symbol: category.symbol, color: category.color, size: size)
    }
}

/// A glossy squircle with a white glyph, tinted with the given color.
struct SymbolBadge: View {
    let symbol: String
    let color: Color
    var size: CGFloat = 44
    var gradient: LinearGradient?

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: size * 0.32, style: .continuous)
        Image(systemName: symbol)
            .font(.system(size: size * 0.42, weight: .semibold))
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.18), radius: 1, y: 1)
            .frame(width: size, height: size)
            .background {
                shape.fill(gradient ?? Gradients.tint(color))
                shape.fill(LinearGradient(colors: [.white.opacity(0.28), .clear],
                                          startPoint: .top, endPoint: .center))
            }
            .overlay(shape.strokeBorder(.white.opacity(0.18), lineWidth: 0.5))
            .shadow(color: color.opacity(0.28), radius: size * 0.14, y: size * 0.08)
            .accessibilityHidden(true)
    }
}

// MARK: - Entries

struct EntryRow: View {
    let entry: LedgerEntry
    let currency: CurrencyCode
    var showDate = true

    var body: some View {
        let isIncome = entry.kind == .income
        HStack(spacing: 14) {
            CategoryBadge(category: entry.category, size: 44)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Text(entry.title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Palette.ink)
                        .lineLimit(1)
                    if entry.ruleID != nil {
                        Image(systemName: "repeat")
                            .font(.caption2.weight(.heavy))
                            .foregroundStyle(Palette.faint)
                            .accessibilityLabel("Recurring")
                    }
                    if entry.hasReceipt {
                        Image(systemName: "paperclip")
                            .font(.caption2.weight(.heavy))
                            .foregroundStyle(Palette.faint)
                            .accessibilityLabel("Has receipt")
                    }
                }
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(Palette.muted)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            Text(Money.signed(entry.amountCents, kind: entry.kind, currency: currency))
                .font(Typography.money(16, weight: .bold))
                .foregroundStyle(isIncome ? Palette.green : Palette.ink)
                .multilineTextAlignment(.trailing)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(entry.title), \(isIncome ? "income" : "expense"), \(Money.format(entry.amountCents, currency: currency)), \(DateText.long(entry.date)), \(entry.category.label)")
        .accessibilityAddTraits(.isButton)
    }

    private var subtitle: String {
        if showDate { return "\(entry.category.label) · \(DateText.relativeDay(entry.date))" }
        if !entry.note.isEmpty { return "\(entry.category.label) · \(entry.note)" }
        return entry.category.label
    }
}

// MARK: - Progress

struct ProgressBar: View {
    let value: Double
    var tint: AnyShapeStyle = AnyShapeStyle(Palette.blue)
    var track: Color = Palette.line
    var height: CGFloat = 8
    /// Optional 0–1 position of a "where you should be" tick.
    var marker: Double?

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            ZStack(alignment: .leading) {
                Capsule().fill(track)
                Capsule()
                    .fill(tint)
                    .frame(width: max(value > 0 ? height : 0, width * min(max(value, 0), 1)))
                if let marker {
                    Capsule()
                        .fill(Color.white)
                        .frame(width: 3, height: height + 8)
                        .shadow(color: .black.opacity(0.25), radius: 2)
                        .offset(x: width * min(max(marker, 0), 1) - 1.5)
                }
            }
        }
        .frame(height: height)
        .animation(.spring(response: 0.6, dampingFraction: 0.85), value: value)
        .accessibilityHidden(true)
    }
}

struct RingProgress: View {
    let value: Double
    var lineWidth: CGFloat = 10
    var colors: [Color] = [Color(hex: 0xA8DC40), Color(hex: 0xD8F36A)]
    var track: Color = Palette.line

    var body: some View {
        ZStack {
            Circle().stroke(track, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: min(max(value, 0.0001), 1))
                .stroke(AngularGradient(colors: colors + [colors.first ?? .white], center: .center,
                                        startAngle: .degrees(0), endAngle: .degrees(360)),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .shadow(color: (colors.last ?? .clear).opacity(0.35), radius: 4)
            if value > 1 {
                Circle()
                    .trim(from: 0, to: min(value - 1, 1))
                    .stroke(Palette.red, style: StrokeStyle(lineWidth: lineWidth * 0.55, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
        }
        .animation(.spring(response: 0.8, dampingFraction: 0.85), value: value)
        .accessibilityHidden(true)
    }
}

// MARK: - Headings

struct SectionHeader: View {
    let title: String
    var subtitle: String?
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.title3.weight(.bold)).foregroundStyle(Palette.ink)
                if let subtitle {
                    Text(subtitle).font(.footnote).foregroundStyle(Palette.muted)
                }
            }
            Spacer(minLength: 8)
            if let actionTitle, let action {
                Button {
                    Haptics.tap()
                    action()
                } label: {
                    HStack(spacing: 3) {
                        Text(actionTitle)
                        Image(systemName: "chevron.right").font(.caption.weight(.bold))
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Palette.blue)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
    }
}

/// Small uppercase label used on hero cards.
struct Eyebrow: View {
    let text: String
    var color: Color = Palette.heroText

    var body: some View {
        Text(text.uppercased())
            .font(Typography.eyebrow)
            .tracking(1.6)
            .foregroundStyle(color)
    }
}

struct SectionTitle: View {
    let title: String
    var subtitle: String?

    var body: some View {
        SectionHeader(title: title, subtitle: subtitle)
    }
}

// MARK: - Chips

struct Chip: View {
    let title: String
    var symbol: String?
    var isSelected: Bool
    var tint: Color = Palette.blue
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.selection()
            action()
        } label: {
            HStack(spacing: 6) {
                if let symbol { Image(systemName: symbol).font(.caption.weight(.bold)) }
                Text(title).font(.subheadline.weight(.semibold)).lineLimit(1)
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 36)
            .foregroundStyle(isSelected ? Color.white : Palette.ink)
            .background {
                Capsule().fill(isSelected ? AnyShapeStyle(Gradients.tint(tint)) : AnyShapeStyle(Palette.surface))
            }
            .overlay(Capsule().strokeBorder(isSelected ? Color.clear : Palette.line, lineWidth: 1))
            .shadow(color: isSelected ? tint.opacity(0.3) : .clear, radius: 6, y: 3)
        }
        .buttonStyle(PressableStyle(scale: 0.95))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// A capsule segmented control that matches Penny's style.
struct PillPicker<Value: Hashable>: View {
    let options: [(Value, String)]
    @Binding var selection: Value
    @Namespace private var namespace

    var body: some View {
        HStack(spacing: 4) {
            ForEach(options.indices, id: \.self) { index in
                let option = options[index]
                let selected = option.0 == selection
                Button {
                    Haptics.selection()
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { selection = option.0 }
                } label: {
                    Text(option.1)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(selected ? Palette.ink : Palette.muted)
                        .frame(maxWidth: .infinity, minHeight: 38)
                        .background {
                            if selected {
                                Capsule()
                                    .fill(Palette.surface)
                                    .shadow(color: .black.opacity(0.08), radius: 6, y: 2)
                                    .matchedGeometryEffect(id: "pill", in: namespace)
                            }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(4)
        .background(Palette.line.opacity(0.6), in: Capsule())
    }
}

// MARK: - Banners & empty states

struct SampleBanner: View {
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "wand.and.stars")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Palette.navy)
                .frame(width: 34, height: 34)
                .background(Gradients.lime, in: Circle())
            VStack(alignment: .leading, spacing: 1) {
                Text("You’re exploring sample data").font(.subheadline.weight(.semibold)).foregroundStyle(Palette.ink)
                Text("Clear it whenever you’re ready to start.").font(.caption).foregroundStyle(Palette.muted)
            }
            Spacer(minLength: 4)
            Button("Clear", action: onRemove)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Palette.blue)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Palette.paleBlue, in: Capsule())
        }
        .card(padding: 12, radius: 20)
    }
}

struct EmptyStateCard: View {
    let symbol: String
    let title: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle().fill(Palette.paleBlue).frame(width: 74, height: 74)
                Image(systemName: symbol)
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(Palette.blue)
                    .symbolRenderingMode(.hierarchical)
            }
            Text(title).font(.headline).foregroundStyle(Palette.ink)
            Text(message)
                .font(.subheadline).foregroundStyle(Palette.muted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            if let actionTitle, let action {
                Button(action: action) {
                    Label(actionTitle, systemImage: "plus")
                        .font(.subheadline.weight(.bold))
                        .padding(.horizontal, 18)
                        .padding(.vertical, 11)
                        .foregroundStyle(.white)
                        .background(Gradients.blue, in: Capsule())
                }
                .buttonStyle(PressableStyle())
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
    }
}

// MARK: - Floating add button

struct FloatingAddButton: View {
    @Environment(AppState.self) private var state

    var body: some View {
        Menu {
            Button { state.add(.expense) } label: { Label("Expense", systemImage: "arrow.up.right") }
            Button { state.add(.income) } label: { Label("Income", systemImage: "arrow.down.left") }
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(Palette.navy)
                .frame(width: 62, height: 62)
                .background {
                    Circle().fill(Gradients.lime)
                    Circle().fill(LinearGradient(colors: [.white.opacity(0.5), .clear], startPoint: .top, endPoint: .center))
                }
                .overlay(Circle().strokeBorder(.white.opacity(0.6), lineWidth: 1))
                .shadow(color: Palette.limeDeep.opacity(0.5), radius: 14, y: 6)
                .shadow(color: .black.opacity(0.18), radius: 4, y: 2)
        } primaryAction: {
            state.add(.expense)
        }
        .accessibilityLabel("Add transaction")
        .accessibilityHint("Double tap to add an expense. Touch and hold for more options.")
        .padding(.trailing, 20)
        .padding(.bottom, 14)
    }
}

// MARK: - Toast with undo

struct ToastView: View {
    @Environment(AppState.self) private var state
    let toast: Toast

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: toast.symbol)
                .font(.headline)
                .foregroundStyle(Palette.lime)
            Text(toast.message)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let undo = toast.undo {
                Button {
                    Haptics.tap()
                    undo()
                    state.toast = nil
                } label: {
                    Text("Undo")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Palette.navy)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(Palette.lime, in: Capsule())
                }
            }
        }
        .padding(.leading, 18)
        .padding(.trailing, toast.undo == nil ? 18 : 8)
        .padding(.vertical, toast.undo == nil ? 15 : 8)
        .background {
            Capsule().fill(Palette.navy.opacity(0.94))
            Capsule().fill(.ultraThinMaterial).opacity(0.2)
        }
        .overlay(Capsule().strokeBorder(.white.opacity(0.12)))
        .shadow(color: .black.opacity(0.25), radius: 18, y: 8)
        .padding(.horizontal, 16)
        .task(id: toast.id) {
            try? await Task.sleep(for: .seconds(5))
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
            HeroBackground()
                .ignoresSafeArea()
            VStack(spacing: 20) {
                Spacer()
                BrandMark(size: 92)
                VStack(spacing: 6) {
                    Text("Penny is locked")
                        .font(.title.weight(.bold))
                        .foregroundStyle(.white)
                    Text(lock.message ?? "Your finances stay private.")
                        .font(.subheadline)
                        .foregroundStyle(Palette.heroText)
                }
                Spacer()
                Button {
                    Task { await lock.unlock() }
                } label: {
                    Label("Unlock with \(AppLock.methodName)", systemImage: AppLock.methodSymbol)
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(lock.isAuthenticating)
                .padding(.horizontal, 28)
                .padding(.bottom, 24)
            }
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
            HeroBackground().ignoresSafeArea()
            BrandMark(size: 92)
        }
    }
}

struct BrandMark: View {
    var size: CGFloat = 40

    var body: some View {
        Image("Logo")
            .resizable()
            .interpolation(.high)
            .scaledToFill()
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.235, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: size * 0.235, style: .continuous)
                .strokeBorder(.white.opacity(0.18), lineWidth: 0.5))
            .shadow(color: .black.opacity(0.25), radius: size * 0.12, y: size * 0.06)
            .accessibilityHidden(true)
    }
}

// MARK: - Confetti

/// A short burst of falling confetti. Changing `trigger` starts a new burst.
struct ConfettiView: View {
    let trigger: Int

    private struct Piece {
        let x: CGFloat
        let drift: CGFloat
        let speed: CGFloat
        let spin: Double
        let color: Color
        let size: CGSize
        let delay: Double
        let isCircle: Bool
    }

    @State private var start: Date?
    @State private var pieces: [Piece] = []

    private static let colors: [Color] = [
        Color(hex: 0xD8F36A), Color(hex: 0x6E8BFF), Color(hex: 0xFF8A7A),
        Color(hex: 0x4ADE80), Color(hex: 0xFBBF24), Color(hex: 0xE879F9), .white,
    ]

    var body: some View {
        TimelineView(.animation(minimumInterval: nil, paused: start == nil)) { timeline in
            Canvas { context, size in
                guard let start else { return }
                let elapsed = timeline.date.timeIntervalSince(start)
                for piece in pieces {
                    let t = elapsed - piece.delay
                    guard t > 0 else { continue }
                    let x = piece.x * size.width + piece.drift * CGFloat(t) + sin(CGFloat(t) * 3 + piece.x * 10) * 18
                    let y = -30 + piece.speed * CGFloat(t) + 140 * CGFloat(t * t)
                    guard y < size.height + 40 else { continue }
                    let fade = max(0, min(1, 3.2 - elapsed))
                    var copy = context
                    copy.translateBy(x: x, y: y)
                    copy.rotate(by: .radians(piece.spin * t))
                    copy.scaleBy(x: 1, y: CGFloat(abs(cos(piece.spin * t * 0.7)) * 0.8 + 0.2))
                    let rect = CGRect(x: -piece.size.width / 2, y: -piece.size.height / 2,
                                      width: piece.size.width, height: piece.size.height)
                    let path = piece.isCircle ? Path(ellipseIn: rect) : Path(roundedRect: rect, cornerRadius: 1.5)
                    copy.fill(path, with: .color(piece.color.opacity(fade)))
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onChange(of: trigger) { _, _ in burst() }
    }

    private func burst() {
        pieces = (0..<110).map { _ in
            Piece(x: .random(in: 0...1),
                  drift: .random(in: -60...60),
                  speed: .random(in: 120...380),
                  spin: .random(in: 3...12) * (Bool.random() ? 1 : -1),
                  color: Self.colors.randomElement() ?? .white,
                  size: CGSize(width: .random(in: 6...11), height: .random(in: 9...16)),
                  delay: .random(in: 0...0.5),
                  isCircle: Int.random(in: 0..<5) == 0)
        }
        let begin = Date()
        start = begin
        Task {
            try? await Task.sleep(for: .seconds(3.6))
            if start == begin { start = nil }
        }
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

// MARK: - Screenshot helper

/// Scrolls a long screen to "more" / "end" anchors when the screenshot script asks for it.
struct ScreenshotScroller: ViewModifier {
    let proxy: ScrollViewProxy

    func body(content: Content) -> some View {
        content.task {
            guard LaunchOptions.isScreenshotMode, let target = LaunchOptions.scrollTarget else { return }
            try? await Task.sleep(for: .seconds(1.2))
            withAnimation { proxy.scrollTo(target, anchor: target == "end" ? .bottom : .top) }
        }
    }
}

extension View {
    func screenshotScroll(_ proxy: ScrollViewProxy) -> some View { modifier(ScreenshotScroller(proxy: proxy)) }
}
