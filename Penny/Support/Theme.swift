import SwiftUI
import UIKit

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
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

/// Penny's high-contrast palette: deep navy, cobalt actions, lime emphasis.
enum Palette {
    static let navy = Color(hex: 0x14213D)
    static let lime = Color(hex: 0xD8F36A)
    static let heroText = Color(hex: 0xDAE1F0)
    static let heroTrack = Color(hex: 0x64748B)
    static let blue = Color.dynamic(light: 0x2549D8, dark: 0x8FA6FF)
    static let green = Color.dynamic(light: 0x156B46, dark: 0x5FD39B)
    static let red = Color.dynamic(light: 0xB42318, dark: 0xFF8A80)
    static let ink = Color.dynamic(light: 0x14213D, dark: 0xF1F4FA)
    static let muted = Color.dynamic(light: 0x526078, dark: 0xA9B4C8)
    static let background = Color.dynamic(light: 0xF3F5FA, dark: 0x0B1224)
    static let surface = Color.dynamic(light: 0xFFFFFF, dark: 0x16203A)
    static let line = Color.dynamic(light: 0xD9DFE9, dark: 0x2A3654)
    static let paleBlue = Color.dynamic(light: 0xEDF1FF, dark: 0x1E2A4D)
}

struct CardModifier: ViewModifier {
    var padding: CGFloat
    var fill: Color
    var bordered: Bool

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(fill, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                if bordered {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(Palette.line, lineWidth: 1)
                }
            }
    }
}

extension View {
    func card(padding: CGFloat = 20, fill: Color = Palette.surface, bordered: Bool = true) -> some View {
        modifier(CardModifier(padding: padding, fill: fill, bordered: bordered))
    }
}
