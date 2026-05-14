import SwiftUI

// MARK: - Theme Variant

enum ThemeVariant: String, CaseIterable, Identifiable {
    case pink = "粉色"
    case blue = "藍色"
    var id: String { rawValue }

    var icon: String {
        switch self {
        case .pink: return "🌸"
        case .blue: return "🫧"
        }
    }
}

// MARK: - App-wide design tokens

enum AppTheme {
    // ── Themed (depend on UserDefaults "appTheme") ─────────────

    private static var isPink: Bool {
        (UserDefaults.standard.string(forKey: "appTheme") ?? "粉色") != "藍色"
    }

    static var bg: Color {
        isPink ? Color(hex: "FFF5F9") : Color(hex: "EFF6FF")
    }
    static var primary: Color {
        isPink ? Color(hex: "FF6B9D") : Color(hex: "3B82F6")
    }
    static var primaryLight: Color {
        isPink ? Color(hex: "FFE4F0") : Color(hex: "DBEAFE")
    }
    static var primaryGradient: LinearGradient {
        isPink
            ? LinearGradient(colors: [Color(hex: "FF6B9D"), Color(hex: "FF8E53")],
                             startPoint: .topLeading, endPoint: .bottomTrailing)
            : LinearGradient(colors: [Color(hex: "3B82F6"), Color(hex: "06B6D4")],
                             startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    // backward-compat aliases
    static var pink:         Color           { primary }
    static var pinkLight:    Color           { primaryLight }
    static var pinkGradient: LinearGradient  { primaryGradient }

    // ── Static (non-themed) ────────────────────────────────────

    static let surface = Color.white

    static let mint        = Color(hex: "4ECDC4")
    static let mintLight   = Color(hex: "D4F5F3")
    static let coral       = Color(hex: "FF8E53")
    static let coralLight  = Color(hex: "FFE8D9")
    static let yellow      = Color(hex: "FFD93D")
    static let yellowLight = Color(hex: "FFF6CC")
    static let purple      = Color(hex: "A78BFA")
    static let purpleLight = Color(hex: "EDE9FE")

    static let textPrimary   = Color(hex: "3D2C44")
    static let textSecondary = Color(hex: "9B8AA3")
    static let border        = Color(hex: "F3E8F0")

    static let mintGradient = LinearGradient(
        colors: [Color(hex: "4ECDC4"), Color(hex: "44CF6C")],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
    static let coralGradient = LinearGradient(
        colors: [Color(hex: "FF8E53"), Color(hex: "FFD93D")],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )

    // ── Corner radii ───────────────────────────────────────────

    static let radiusCard:   CGFloat = 24
    static let radiusRow:    CGFloat = 18
    static let radiusChip:   CGFloat = 12
    static let radiusKey:    CGFloat = 14
}

// MARK: - View Modifiers

extension View {
    func cuteCard() -> some View {
        self
            .background(AppTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusCard, style: .continuous))
            .shadow(color: AppTheme.primary.opacity(0.10), radius: 14, y: 4)
    }
    func cuteRow() -> some View {
        self
            .background(AppTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusRow, style: .continuous))
            .shadow(color: AppTheme.primary.opacity(0.07), radius: 8, y: 3)
    }
}
