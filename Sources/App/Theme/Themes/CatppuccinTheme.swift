import SwiftUI

// MARK: - Catppuccin Palette

/// The 26 colors of a Catppuccin flavor.
/// Names and values follow the official palette: https://catppuccin.com/palette/
struct CatppuccinPalette {
    let rosewater: Color
    let flamingo: Color
    let pink: Color
    let mauve: Color
    let red: Color
    let maroon: Color
    let peach: Color
    let yellow: Color
    let green: Color
    let teal: Color
    let sky: Color
    let sapphire: Color
    let blue: Color
    let lavender: Color
    let text: Color
    let subtext1: Color
    let subtext0: Color
    let overlay2: Color
    let overlay1: Color
    let overlay0: Color
    let surface2: Color
    let surface1: Color
    let surface0: Color
    let base: Color
    let mantle: Color
    let crust: Color
}

/// Builds a `Color` from a 0xRRGGBB literal.
private func cc(_ hex: UInt32) -> Color {
    Color(
        red: Double((hex >> 16) & 0xFF) / 255,
        green: Double((hex >> 8) & 0xFF) / 255,
        blue: Double(hex & 0xFF) / 255
    )
}

// MARK: - Catppuccin Flavor

/// The four official Catppuccin flavors, ordered light-to-dark.
public enum CatppuccinFlavor: String, CaseIterable, Hashable, Sendable {
    case latte
    case frappe
    case macchiato
    case mocha

    public var displayName: String {
        switch self {
        case .latte: "Latte"
        case .frappe: "Frappé"
        case .macchiato: "Macchiato"
        case .mocha: "Mocha"
        }
    }

    /// Latte is the only light flavor; the rest are dark.
    var isLight: Bool { self == .latte }

    var palette: CatppuccinPalette {
        switch self {
        case .latte:
            CatppuccinPalette(
                rosewater: cc(0xDC8A78), flamingo: cc(0xDD7878), pink: cc(0xEA76CB),
                mauve: cc(0x8839EF), red: cc(0xD20F39), maroon: cc(0xE64553),
                peach: cc(0xFE640B), yellow: cc(0xDF8E1D), green: cc(0x40A02B),
                teal: cc(0x179299), sky: cc(0x04A5E5), sapphire: cc(0x209FB5),
                blue: cc(0x1E66F5), lavender: cc(0x7287FD), text: cc(0x4C4F69),
                subtext1: cc(0x5C5F77), subtext0: cc(0x6C6F85), overlay2: cc(0x7C7F93),
                overlay1: cc(0x8C8FA1), overlay0: cc(0x9CA0B0), surface2: cc(0xACB0BE),
                surface1: cc(0xBCC0CC), surface0: cc(0xCCD0DA), base: cc(0xEFF1F5),
                mantle: cc(0xE6E9EF), crust: cc(0xDCE0E8)
            )
        case .frappe:
            CatppuccinPalette(
                rosewater: cc(0xF2D5CF), flamingo: cc(0xEEBEBE), pink: cc(0xF4B8E4),
                mauve: cc(0xCA9EE6), red: cc(0xE78284), maroon: cc(0xEA999C),
                peach: cc(0xEF9F76), yellow: cc(0xE5C890), green: cc(0xA6D189),
                teal: cc(0x81C8BE), sky: cc(0x99D1DB), sapphire: cc(0x85C1DC),
                blue: cc(0x8CAAEE), lavender: cc(0xBABBF1), text: cc(0xC6D0F5),
                subtext1: cc(0xB5BFE2), subtext0: cc(0xA5ADCE), overlay2: cc(0x949CBB),
                overlay1: cc(0x838BA7), overlay0: cc(0x737994), surface2: cc(0x626880),
                surface1: cc(0x51576D), surface0: cc(0x414559), base: cc(0x303446),
                mantle: cc(0x292C3C), crust: cc(0x232634)
            )
        case .macchiato:
            CatppuccinPalette(
                rosewater: cc(0xF4DBD6), flamingo: cc(0xF0C6C6), pink: cc(0xF5BDE6),
                mauve: cc(0xC6A0F6), red: cc(0xED8796), maroon: cc(0xEE99A0),
                peach: cc(0xF5A97F), yellow: cc(0xEED49F), green: cc(0xA6DA95),
                teal: cc(0x8BD5CA), sky: cc(0x91D7E3), sapphire: cc(0x7DC4E4),
                blue: cc(0x8AADF4), lavender: cc(0xB7BDF8), text: cc(0xCAD3F5),
                subtext1: cc(0xB8C0E0), subtext0: cc(0xA5ADCB), overlay2: cc(0x939AB7),
                overlay1: cc(0x8087A2), overlay0: cc(0x6E738D), surface2: cc(0x5B6078),
                surface1: cc(0x494D64), surface0: cc(0x363A4F), base: cc(0x24273A),
                mantle: cc(0x1E2030), crust: cc(0x181926)
            )
        case .mocha:
            CatppuccinPalette(
                rosewater: cc(0xF5E0DC), flamingo: cc(0xF2CDCD), pink: cc(0xF5C2E7),
                mauve: cc(0xCBA6F7), red: cc(0xF38BA8), maroon: cc(0xEBA0AC),
                peach: cc(0xFAB387), yellow: cc(0xF9E2AF), green: cc(0xA6E3A1),
                teal: cc(0x94E2D5), sky: cc(0x89DCEB), sapphire: cc(0x74C7EC),
                blue: cc(0x89B4FA), lavender: cc(0xB4BEFE), text: cc(0xCDD6F4),
                subtext1: cc(0xBAC2DE), subtext0: cc(0xA6ADC8), overlay2: cc(0x9399B2),
                overlay1: cc(0x7F849C), overlay0: cc(0x6C7086), surface2: cc(0x585B70),
                surface1: cc(0x45475A), surface0: cc(0x313244), base: cc(0x1E1E2E),
                mantle: cc(0x181825), crust: cc(0x11111B)
            )
        }
    }
}

// MARK: - Catppuccin Theme

/// A theme built from a single Catppuccin flavor.
///
/// The palette drives every role: `mauve` and `blue` are the accents, the
/// status colors walk yellow → peach → red for warning → critical → depleted,
/// and the surfaces/overlays back the glass cards.
public struct CatppuccinTheme: AppThemeProvider {
    public let flavor: CatppuccinFlavor

    public init(flavor: CatppuccinFlavor) {
        self.flavor = flavor
    }

    // MARK: - Identity

    public var id: String { "catppuccin-\(flavor.rawValue)" }
    public var displayName: String { flavor.displayName }
    public let icon = "cup.and.saucer.fill"
    public var subtitle: String? { "Catppuccin" }

    // MARK: - Shortcuts

    private var p: CatppuccinPalette { flavor.palette }
    private var isLight: Bool { flavor.isLight }

    // MARK: - Background

    public var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [p.crust, p.mantle, p.base],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    public var showBackgroundOrbs: Bool { true }

    // MARK: - Cards & Glass

    public var cardGradient: LinearGradient {
        LinearGradient(
            colors: isLight
                ? [Color.white.opacity(0.92), Color.white.opacity(0.72)]
                : [p.surface0.opacity(0.85), p.surface1.opacity(0.55)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    public var glassBackground: Color {
        isLight ? Color.white.opacity(0.70) : p.surface0.opacity(0.55)
    }

    public var glassBorder: Color {
        p.overlay0.opacity(isLight ? 0.35 : 0.50)
    }

    public var glassHighlight: Color {
        isLight ? Color.white.opacity(0.90) : p.text.opacity(0.30)
    }

    public var cardCornerRadius: CGFloat { 14 }
    public var pillCornerRadius: CGFloat { 20 }

    // MARK: - Typography

    public var textPrimary: Color { p.text }
    public var textSecondary: Color { p.subtext1 }
    public var textTertiary: Color { p.overlay1 }
    public var fontDesign: Font.Design { .rounded }

    // MARK: - Status Colors

    public var statusHealthy: Color { p.green }
    public var statusWarning: Color { p.yellow }
    public var statusCritical: Color { p.peach }
    public var statusDepleted: Color { p.red }

    // MARK: - Accents

    public var accentPrimary: Color { p.mauve }
    public var accentSecondary: Color { p.blue }

    public var accentGradient: LinearGradient {
        LinearGradient(
            colors: [p.pink, p.mauve],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    public var pillGradient: LinearGradient {
        LinearGradient(
            colors: [p.mauve.opacity(0.60), p.pink.opacity(0.40)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    public var shareGradient: LinearGradient {
        LinearGradient(
            colors: [p.yellow, p.peach],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: - Interactive States

    public var hoverOverlay: Color {
        p.text.opacity(isLight ? 0.05 : 0.08)
    }

    public var pressedOverlay: Color {
        p.text.opacity(isLight ? 0.08 : 0.12)
    }

    // MARK: - Progress Bar

    public var progressTrack: Color {
        isLight ? p.surface0 : p.surface1
    }
}
