import AppKit
import CoreText
import SwiftUI

/// Riven's design system (`rivendevs-site/design.md`) applied to WallLoop's own UI.
///
/// Neutrals, type, spacing, radii and motion come from Riven. The accent is WallLoop's
/// own rose: Riven products keep their own colour, as Clareo keeps its lime. Like
/// Riven's orange, it's the only accent, it's rare (primary buttons, active states,
/// one glow per view), and text on it is always black.
enum Theme {
    // MARK: Colour (design.md §2)

    static let bg = Color(hex: 0x070707)
    static let bg2 = Color(hex: 0x0E0E0F)
    static let surface = Color(hex: 0x141415)
    static let surface2 = Color(hex: 0x1C1C1E)
    static let line = Color(hex: 0x26262A)
    static let lineStrong = Color(hex: 0x3A3A40)
    static let ink = Color(hex: 0xF4F2EE)
    static let muted = Color(hex: 0xA3A1A0)
    static let faint = Color(hex: 0x6E6C6B)
    static let success = Color(hex: 0x3DDC97)
    static let danger = Color(hex: 0xFF4D4D)
    /// Warnings, such as a folder WallLoop lost access to (Riven's Tailwind `amber`).
    static let amber = Color(hex: 0xFFB02E)

    /// WallLoop rose. Black text on it is 7.1:1; on `bg` it's 6.9:1.
    static let accent = Color(hex: 0xFF5C8A)
    static let accentHot = Color(hex: 0xFF7EA2)
    static let accentDeep = Color(hex: 0xD93A6A)
    static let accentGlow = Color(hex: 0xFF5C8A, opacity: 0.18)
    static let accentTint = Color(hex: 0xFF5C8A, opacity: 0.08)
    /// Text and icons placed on an accent fill.
    static let onAccent = Color.black

    /// The subtle inner top highlight Riven uses for elevation instead of shadows.
    static let highlight = Color.white.opacity(0.04)

    // MARK: Shape and spacing (design.md §4)

    enum Radius {
        static let input: CGFloat = 12
        static let card: CGFloat = 20
        static let panel: CGFloat = 28
    }

    /// Riven's spacing scale: 4, 8, 12, 16, 24, 32, 48, 64.
    enum Space {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let s: CGFloat = 12
        static let m: CGFloat = 16
        static let l: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
        static let xxxl: CGFloat = 64
    }

    // MARK: Motion (design.md §6)

    /// Entrances: `cubic-bezier(.16, 1, .3, 1)`.
    static func easeOut(_ duration: Double = 0.35) -> Animation {
        .timingCurve(0.16, 1, 0.3, 1, duration: duration)
    }

    /// State changes: `cubic-bezier(.65, 0, .35, 1)`.
    static func easeInOut(_ duration: Double = 0.35) -> Animation {
        .timingCurve(0.65, 0, 0.35, 1, duration: duration)
    }

    static let fast = 0.15
    static let medium = 0.35
    static let slow = 0.7

    // MARK: Type (design.md §3)

    /// Instrument Sans: headings (500–700) and body (400).
    static func sans(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .custom("Instrument Sans", size: size).weight(weight)
    }

    /// Instrument Serif italic: one or two accent words per heading.
    static func serif(_ size: CGFloat) -> Font {
        .custom("Instrument Serif", size: size).italic()
    }

    /// DM Mono: numbers, labels and code. Micro labels are uppercase with 0.08em tracking.
    static func mono(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .custom("DM Mono", size: size).weight(weight)
    }

    /// Makes the bundled fonts available to this process. Call once at launch.
    static func registerFonts(in directory: URL? = Bundle.main.resourceURL) {
        guard let directory,
              let files = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: nil)
        else { return }
        for case let url as URL in files where url.pathExtension.lowercased() == "ttf" {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}

extension Color {
    /// A colour from a 0xRRGGBB value in sRGB.
    init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: opacity)
    }
}

extension View {
    /// Riven's micro label: DM Mono, uppercase, wide tracking, faint.
    func microLabel(_ color: Color = Theme.faint) -> some View {
        font(Theme.mono(11, .medium))
            .tracking(0.9)
            .textCase(.uppercase)
            .foregroundStyle(color)
    }
}
