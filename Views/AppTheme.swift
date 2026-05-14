import SwiftUI

// MARK: - Theme Variant

enum ThemeVariant: String, CaseIterable, Identifiable {
    case pink        = "粉色"
    case blue        = "藍色"
    case systemLight = "淺色"
    case systemDark  = "深色"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .pink:        return "🌸"
        case .blue:        return "🫧"
        case .systemLight: return "☀️"
        case .systemDark:  return "🌙"
        }
    }

    /// Forces the whole app into light or dark mode.
    /// Pink / Blue / Light → always light (nav title = black on light bg)
    /// Dark → always dark
    var preferredColorScheme: ColorScheme {
        self == .systemDark ? .dark : .light
    }
}

// MARK: - App-wide design tokens

enum AppTheme {

    // ── Current theme ────────────────────────────────────────────
    static var current: ThemeVariant {
        let raw = UserDefaults.standard.string(forKey: "appTheme") ?? ThemeVariant.pink.rawValue
        return ThemeVariant(rawValue: raw) ?? .pink
    }

    // ── Themed colours ───────────────────────────────────────────

    static var bg: Color {
        switch current {
        case .pink:        return Color(hex: "FFF5F9")
        case .blue:        return Color(hex: "EFF6FF")
        case .systemLight: return Color(hex: "F2F2F7")
        case .systemDark:  return Color(hex: "1C1C1E")
        }
    }

    static var surface: Color {
        switch current {
        case .systemDark: return Color(hex: "2C2C2E")
        default:          return .white
        }
    }

    static var primary: Color {
        switch current {
        case .pink:        return Color(hex: "FF6B9D")
        case .blue:        return Color(hex: "3B82F6")
        case .systemLight: return Color(hex: "007AFF")
        case .systemDark:  return Color(hex: "0A84FF")
        }
    }

    static var primaryLight: Color {
        switch current {
        case .pink:        return Color(hex: "FFE4F0")
        case .blue:        return Color(hex: "DBEAFE")
        case .systemLight: return Color(hex: "E0F0FF")
        case .systemDark:  return Color(hex: "1C3A5A")
        }
    }

    static var primaryGradient: LinearGradient {
        switch current {
        case .pink:
            return LinearGradient(colors: [Color(hex: "FF6B9D"), Color(hex: "FF8E53")],
                                  startPoint: .topLeading, endPoint: .bottomTrailing)
        case .blue:
            return LinearGradient(colors: [Color(hex: "3B82F6"), Color(hex: "06B6D4")],
                                  startPoint: .topLeading, endPoint: .bottomTrailing)
        case .systemLight:
            return LinearGradient(colors: [Color(hex: "007AFF"), Color(hex: "34AADC")],
                                  startPoint: .topLeading, endPoint: .bottomTrailing)
        case .systemDark:
            return LinearGradient(colors: [Color(hex: "0A84FF"), Color(hex: "30D5C8")],
                                  startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    static var textPrimary: Color {
        switch current {
        case .pink:        return Color(hex: "3D2C44")
        case .blue:        return Color(hex: "1E3A5F")
        case .systemLight: return Color(hex: "1C1C1E")
        case .systemDark:  return Color(hex: "F2F2F7")
        }
    }

    static var textSecondary: Color {
        switch current {
        case .pink:        return Color(hex: "9B8AA3")
        case .blue:        return Color(hex: "6B8BB5")
        case .systemLight: return Color(hex: "6C6C70")
        case .systemDark:  return Color(hex: "8E8E93")
        }
    }

    static var border: Color {
        switch current {
        case .pink:        return Color(hex: "F3E8F0")
        case .blue:        return Color(hex: "DBEAFE")
        case .systemLight: return Color(hex: "D1D1D6")
        case .systemDark:  return Color(hex: "3A3A3C")
        }
    }

    // backward-compat aliases
    static var pink:         Color           { primary }
    static var pinkLight:    Color           { primaryLight }
    static var pinkGradient: LinearGradient  { primaryGradient }

    // ── Non-themed static colours ─────────────────────────────────

    static let mint        = Color(hex: "4ECDC4")
    static let mintLight   = Color(hex: "D4F5F3")
    static let coral       = Color(hex: "FF8E53")
    static let coralLight  = Color(hex: "FFE8D9")
    static let yellow      = Color(hex: "FFD93D")
    static let yellowLight = Color(hex: "FFF6CC")
    static let purple      = Color(hex: "A78BFA")
    static let purpleLight = Color(hex: "EDE9FE")

    static let mintGradient = LinearGradient(
        colors: [Color(hex: "4ECDC4"), Color(hex: "44CF6C")],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
    static let coralGradient = LinearGradient(
        colors: [Color(hex: "FF8E53"), Color(hex: "FFD93D")],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )

    // ── Corner radii ──────────────────────────────────────────────

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
