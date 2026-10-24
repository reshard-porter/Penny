import SwiftUI
import UIKit

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: opacity)
    }

    /// A color that switches automatically between light and dark mode.
    static func dynamic(light: UInt32, dark: UInt32) -> Color {
        Color(UIColor { traits in
            let hex = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: CGFloat((hex >> 16) & 0xFF) / 255,
                           green: CGFloat((hex >> 8) & 0xFF) / 255,
                           blue: CGFloat(hex & 0xFF) / 255,
                           alpha: 1)
        })
    }
}

/// Penny's palette: deep indigo night, electric lime, cobalt actions.
enum Palette {
    // Brand (fixed in both appearances)
    static let navy = Color(hex: 0x0E1740)
    static let indigo = Color(hex: 0x1F3189)
    static let midnight = Color(hex: 0x060A1F)
    static let lime = Color(hex: 0xD8F36A)
    static let limeDeep = Color(hex: 0x9ED53A)
    static let heroText = Color.white.opacity(0.74)
    static let heroFaint = Color.white.opacity(0.5)
    static let heroTrack = Color.white.opacity(0.14)

    // Semantic (adapt to light/dark)
    static let blue = Color.dynamic(light: 0x3552F2, dark: 0x8EA2FF)
    static let green = Color.dynamic(light: 0x0E8A50, dark: 0x4ADE80)
    static let red = Color.dynamic(light: 0xD92D20, dark: 0xFF7B72)
    static let orange = Color.dynamic(light: 0xC2620A, dark: 0xFBBF24)
    static let ink = Color.dynamic(light: 0x0B1433, dark: 0xF3F5FB)
    static let muted = Color.dynamic(light: 0x5B6681, dark: 0x9AA6C1)
    static let faint = Color.dynamic(light: 0x8E98B0, dark: 0x66728F)
    static let background = Color.dynamic(light: 0xF2F4FA, dark: 0x04071A)
    static let surface = Color.dynamic(light: 0xFFFFFF, dark: 0x0F1530)
    static let surfaceRaised = Color.dynamic(light: 0xF5F7FC, dark: 0x182042)
    static let line = Color.dynamic(light: 0xE3E7F0, dark: 0x232C50)
    static let paleBlue = Color.dynamic(light: 0xEBF0FF, dark: 0x18224A)
    static let paleLime = Color.dynamic(light: 0xF3FBD3, dark: 0x1E2A12)
}

enum Gradients {
    static let hero = LinearGradient(
        colors: [Color(hex: 0x2A40B8), Color(hex: 0x15206A), Color(hex: 0x070B24)],
        startPoint: .topLeading, endPoint: .bottomTrailing)
    static let lime = LinearGradient(
        colors: [Color(hex: 0xF0FFA8), Color(hex: 0xD8F36A), Color(hex: 0xA8DC40)],
        startPoint: .topLeading, endPoint: .bottomTrailing)
    static let blue = LinearGradient(
        colors: [Color(hex: 0x6E8BFF), Color(hex: 0x3552F2)],
        startPoint: .top, endPoint: .bottom)
    static let danger = LinearGradient(
        colors: [Color(hex: 0xFF8A7A), Color(hex: 0xE5372A)],
        startPoint: .topLeading, endPoint: .bottomTrailing)

    static func tint(_ color: Color) -> LinearGradient {
        LinearGradient(colors: [color.opacity(0.78), color], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

enum Typography {
    /// Rounded, tabular numerals for amounts.
    static func money(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .rounded).monospacedDigit()
    }

    static let eyebrow = Font.caption2.weight(.heavy)
}

// MARK: - Hero background

/// The glowing night-sky gradient used on hero cards, the lock screen and onboarding.
struct HeroBackground: View {
    var glow: Color = Palette.lime
    var secondGlow: Color = Color(hex: 0x6E8BFF)
    var rings = true

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                Gradients.hero
                Circle()
                    .fill(glow.opacity(0.42))
                    .frame(width: size.width * 0.8)
                    .blur(radius: 60)
                    .offset(x: size.width * 0.38, y: -size.height * 0.42)
                Circle()
                    .fill(secondGlow.opacity(0.45))
                    .frame(width: size.width * 0.7)
                    .blur(radius: 70)
                    .offset(x: -size.width * 0.42, y: size.height * 0.5)
                if rings {
                    Canvas { context, canvasSize in
                        let center = CGPoint(x: canvasSize.width * 0.92, y: canvasSize.height * 0.05)
                        for index in 1...6 {
                            let radius = CGFloat(index) * 46
                            let rect = CGRect(x: center.x - radius, y: center.y - radius,
                                              width: radius * 2, height: radius * 2)
                            context.stroke(Path(ellipseIn: rect),
                                           with: .color(.white.opacity(0.07 - Double(index) * 0.008)),
                                           lineWidth: 1)
                        }
                    }
                }
                LinearGradient(colors: [.white.opacity(0.10), .clear], startPoint: .top, endPoint: .center)
            }
            .frame(width: size.width, height: size.height)
            .clipped()
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Cards

struct CardModifier: ViewModifier {
    @Environment(\.colorScheme) private var scheme
    var padding: CGFloat
    var fill: Color
    var radius: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(fill)
                    .shadow(color: Color(hex: 0x1B2A6B).opacity(scheme == .dark ? 0 : 0.07), radius: 18, y: 8)
                    .shadow(color: Color(hex: 0x1B2A6B).opacity(scheme == .dark ? 0 : 0.04), radius: 2, y: 1)
            }
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(Palette.line.opacity(scheme == .dark ? 1 : 0.6), lineWidth: scheme == .dark ? 1 : 0.5)
            }
    }
}

struct HeroCardModifier: ViewModifier {
    var padding: CGFloat
    var radius: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                HeroBackground()
                    .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
                    .shadow(color: Color(hex: 0x15206A).opacity(0.35), radius: 22, y: 12)
            }
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(LinearGradient(colors: [.white.opacity(0.28), .white.opacity(0.04)],
                                                 startPoint: .topLeading, endPoint: .bottomTrailing),
                                  lineWidth: 1)
            }
            .environment(\.colorScheme, .dark)
    }
}

extension View {
    func card(padding: CGFloat = 18, fill: Color = Palette.surface, radius: CGFloat = 24) -> some View {
        modifier(CardModifier(padding: padding, fill: fill, radius: radius))
    }

    func heroCard(padding: CGFloat = 22, radius: CGFloat = 30) -> some View {
        modifier(HeroCardModifier(padding: padding, radius: radius))
    }

    /// Standard screen background.
    func pennyBackground() -> some View {
        background(Palette.background.ignoresSafeArea())
    }
}

// MARK: - Buttons

/// Gentle press-down scale used on cards and chips.
struct PressableStyle: ButtonStyle {
    var scale: CGFloat = 0.97

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

/// Large lime call-to-action button.
struct PrimaryButtonStyle: ButtonStyle {
    var fill: AnyShapeStyle = AnyShapeStyle(Gradients.lime)
    var foreground: Color = Palette.navy

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(fill, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(.white.opacity(0.35), lineWidth: 1).blendMode(.overlay))
            .shadow(color: Palette.limeDeep.opacity(0.35), radius: configuration.isPressed ? 4 : 12, y: 6)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Haptics

@MainActor
enum Haptics {
    private static var enabled: Bool { !UserDefaults.standard.bool(forKey: "hapticsDisabled") }

    static func tap() {
        guard enabled else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func selection() {
        guard enabled else { return }
        UISelectionFeedbackGenerator().selectionChanged()
    }

    static func success() {
        guard enabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func warning() {
        guard enabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }
}

// MARK: - Appearance

enum AppearanceMode: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: String { rawValue }
    var label: String {
        switch self {
        case .system: return "Automatic"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }
    var symbol: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max.fill"
        case .dark: return "moon.stars.fill"
        }
    }
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}
