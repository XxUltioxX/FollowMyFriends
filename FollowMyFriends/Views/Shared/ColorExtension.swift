import SwiftUI

// MARK: - Design Token Colors

extension Color {
    static let background   = Color(hex: "0E0E10")
    static let surface      = Color(hex: "1C1C1E")
    static let elevated     = Color(hex: "252528")
    static let border       = Color(hex: "252528")
    static let borderFocus  = Color(hex: "3f3f46")
    static let accentBlue   = Color(hex: "3B82F6")
    static let accentGreen  = Color(hex: "22C55E")
    static let accentAmber  = Color(hex: "F59E0B")
    static let accentRed    = Color(hex: "EF4444")
    static let textPrimary  = Color(hex: "F2F2F7")
    static let textSecondary = Color(hex: "9898A0")
    static let textTertiary  = Color(hex: "6B6B75")
}

// MARK: - Hex Initialiser

extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&int)

        let a: UInt64
        let r: UInt64
        let g: UInt64
        let b: UInt64

        switch cleaned.count {
        case 3:  (a, r, g, b) = (255, (int >> 8)*17, (int >> 4 & 0xF)*17, (int & 0xF)*17)
        case 6:  (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:  (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }

        self.init(
            .sRGB,
            red:     Double(r) / 255,
            green:   Double(g) / 255,
            blue:    Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Section Header Style

struct SettingsHeaderStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Color.textSecondary)
            .textCase(.uppercase)
            .tracking(0.5)
    }
}

extension View {
    func settingsHeader() -> some View {
        modifier(SettingsHeaderStyle())
    }
}
