import SwiftUI

extension Color {
    /// Hex like `#E8A04B` or `E8A04B`.
    init(hex: String) {
        let s = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var rgb: UInt64 = 0
        Scanner(string: s).scanHexInt64(&rgb)
        let r = Double((rgb & 0xFF0000) >> 16) / 255
        let g = Double((rgb & 0x00FF00) >> 8) / 255
        let b = Double(rgb & 0x0000FF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: 1)
    }

    /// HSL (degrees, 0–1, 0–1) → Color. The design derives cover gradients from HSL.
    init(hslHue h: Double, saturation s: Double, lightness l: Double) {
        let c = (1 - abs(2 * l - 1)) * s
        let hp = h / 60
        let x = c * (1 - abs(hp.truncatingRemainder(dividingBy: 2) - 1))
        var (r, g, b): (Double, Double, Double)
        switch hp {
        case 0..<1: (r, g, b) = (c, x, 0)
        case 1..<2: (r, g, b) = (x, c, 0)
        case 2..<3: (r, g, b) = (0, c, x)
        case 3..<4: (r, g, b) = (0, x, c)
        case 4..<5: (r, g, b) = (x, 0, c)
        default:    (r, g, b) = (c, 0, x)
        }
        let m = l - c / 2
        self.init(.sRGB, red: r + m, green: g + m, blue: b + m, opacity: 1)
    }
}

/// The Spinefin design system palette. One amber accent over warm neutrals,
/// in a dark-first and light variant — mirrors the tokens in the Claude Design handoff.
struct Palette: Sendable {
    let isDark: Bool
    let bg: Color
    let bg2: Color
    let card: Color
    let cardHi: Color
    let glassFill: Color
    let glassBorder: Color
    let text: Color
    let text2: Color
    let text3: Color
    let sep: Color
    let accent: Color
    let accentSoft: Color
    let onAccent: Color
    let track: Color
    let listBg: Color
    let shadow: Color

    static let dark = Palette(
        isDark: true,
        bg: Color(hex: "15110D"),
        bg2: Color(hex: "1C1712"),
        card: Color(hex: "241D17"),
        cardHi: Color(hex: "2C241D"),
        glassFill: Color.white.opacity(0.06),
        glassBorder: Color.white.opacity(0.10),
        text: Color(hex: "F6EFE4"),
        text2: Color(hex: "F6EFE4").opacity(0.62),
        text3: Color(hex: "F6EFE4").opacity(0.36),
        sep: Color.white.opacity(0.08),
        accent: Color(hex: "E8A04B"),
        accentSoft: Color(hex: "E8A04B").opacity(0.16),
        onAccent: Color(hex: "241403"),
        track: Color.white.opacity(0.14),
        listBg: Color(hex: "1F1A14"),
        shadow: Color.black.opacity(0.45)
    )

    static let light = Palette(
        isDark: false,
        bg: Color(hex: "F4EEE4"),
        bg2: Color(hex: "FBF8F2"),
        card: Color(hex: "FFFFFF"),
        cardHi: Color(hex: "FFFFFF"),
        glassFill: Color(hex: "211A12").opacity(0.05),
        glassBorder: Color.black.opacity(0.07),
        text: Color(hex: "211A12"),
        text2: Color(hex: "211A12").opacity(0.58),
        text3: Color(hex: "211A12").opacity(0.34),
        sep: Color(hex: "211A12").opacity(0.08),
        accent: Color(hex: "D98B33"),
        accentSoft: Color(hex: "D98B33").opacity(0.14),
        onAccent: Color(hex: "FFFFFF"),
        track: Color(hex: "211A12").opacity(0.12),
        listBg: Color(hex: "FFFFFF"),
        shadow: Color(hex: "785A32").opacity(0.16)
    )
}

private struct PaletteKey: EnvironmentKey {
    static let defaultValue: Palette = .dark
}

extension EnvironmentValues {
    var palette: Palette {
        get { self[PaletteKey.self] }
        set { self[PaletteKey.self] = newValue }
    }
}
