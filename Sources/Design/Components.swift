import AppKit
import SwiftUI

// Riven's components (design.md §7) for WallLoop's native UI. Every colour, font,
// radius and duration comes from `Theme`.

// MARK: - Buttons

/// Riven buttons. Primary: accent fill with black text, at most one per view.
/// Secondary: hairline outline that warms to the accent on hover. Ghost: text only.
struct RivenButtonStyle: ButtonStyle {
    enum Kind { case primary, secondary, ghost }
    enum Size { case small, regular, large }

    var kind: Kind = .primary
    var size: Size = .regular

    func makeBody(configuration: Configuration) -> some View {
        RivenButton(configuration: configuration, kind: kind, size: size)
    }
}

extension ButtonStyle where Self == RivenButtonStyle {
    static var rivenPrimary: RivenButtonStyle { RivenButtonStyle(kind: .primary) }
    static var rivenSecondary: RivenButtonStyle { RivenButtonStyle(kind: .secondary) }
    static var rivenGhost: RivenButtonStyle { RivenButtonStyle(kind: .ghost) }
    static func riven(_ kind: RivenButtonStyle.Kind, size: RivenButtonStyle.Size = .regular) -> RivenButtonStyle {
        RivenButtonStyle(kind: kind, size: size)
    }
}

private struct RivenButton: View {
    let configuration: ButtonStyleConfiguration
    let kind: RivenButtonStyle.Kind
    let size: RivenButtonStyle.Size

    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.isFocused) private var isFocused
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovered = false

    private var height: CGFloat {
        switch size {
        case .small: 26
        case .regular: 32
        case .large: 40
        }
    }

    private var fontSize: CGFloat { size == .large ? 14 : 13 }

    private var fill: Color {
        switch kind {
        case .primary:
            configuration.isPressed ? Theme.accentDeep : (isHovered ? Theme.accentHot : Theme.accent)
        case .secondary:
            configuration.isPressed ? Theme.surface2 : (isHovered ? Theme.surface : .clear)
        case .ghost:
            isHovered || configuration.isPressed ? Theme.surface2 : .clear
        }
    }

    private var border: Color {
        switch kind {
        case .primary: .clear
        case .secondary: isHovered ? Theme.accent : Theme.lineStrong
        case .ghost: .clear
        }
    }

    var body: some View {
        configuration.label
            .font(Theme.sans(fontSize, .semibold))
            .labelStyle(.titleAndIcon)
            .foregroundStyle(kind == .primary ? Theme.onAccent : Theme.ink)
            .lineLimit(1)
            .padding(.horizontal, size == .small ? 12 : 18)
            .frame(height: height)
            .background(Capsule().fill(fill))
            .overlay(Capsule().strokeBorder(border, lineWidth: 1))
            .overlay {
                // Focus ring: 3pt glow outside a 1pt accent line (design.md §7).
                if isFocused {
                    Capsule().strokeBorder(Theme.accent, lineWidth: 1)
                        .padding(-2)
                        .overlay(Capsule().strokeBorder(Theme.accentGlow, lineWidth: 3).padding(-5))
                }
            }
            .contentShape(Capsule())
            .opacity(isEnabled ? 1 : 0.4)
            .focusEffectDisabled()
            .onHover { isHovered = $0 && isEnabled }
            .animation(reduceMotion ? nil : Theme.easeOut(Theme.fast), value: isHovered)
            .animation(reduceMotion ? nil : Theme.easeOut(Theme.fast), value: configuration.isPressed)
    }
}

/// A round icon button, for transport controls and row actions.
struct RivenIconButtonStyle: ButtonStyle {
    var diameter: CGFloat = 32
    /// Prominent uses the accent fill (the one per view, e.g. Play).
    var prominent = false

    func makeBody(configuration: Configuration) -> some View {
        RivenIconButton(configuration: configuration, diameter: diameter, prominent: prominent)
    }
}

private struct RivenIconButton: View {
    let configuration: ButtonStyleConfiguration
    let diameter: CGFloat
    let prominent: Bool

    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.isFocused) private var isFocused
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovered = false

    var body: some View {
        configuration.label
            .font(.system(size: diameter * 0.4, weight: .semibold))
            .foregroundStyle(prominent ? Theme.onAccent : (isHovered ? Theme.ink : Theme.muted))
            .frame(width: diameter, height: diameter)
            .background(Circle().fill(prominent
                ? (configuration.isPressed ? Theme.accentDeep : (isHovered ? Theme.accentHot : Theme.accent))
                : (isHovered || configuration.isPressed ? Theme.surface2 : .clear)))
            .overlay {
                if isFocused {
                    Circle().strokeBorder(Theme.accent, lineWidth: 1).padding(-2)
                }
            }
            .contentShape(Circle())
            .opacity(isEnabled ? 1 : 0.35)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.94 : 1)
            .focusEffectDisabled()
            .onHover { isHovered = $0 && isEnabled }
            .animation(reduceMotion ? nil : Theme.easeOut(Theme.fast), value: isHovered)
            .animation(reduceMotion ? nil : Theme.easeOut(Theme.fast), value: configuration.isPressed)
    }
}

// MARK: - Surfaces

extension View {
    /// Riven elevation: a lighter surface, a 1pt hairline border and a faint inner top
    /// highlight, not a heavy drop shadow. Hovered surfaces brighten their border and
    /// pick up a faint accent edge glow.
    func rivenSurface(radius: CGFloat = Theme.Radius.card, fill: Color = Theme.surface,
                      hovered: Bool = false, selected: Bool = false) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        return background(shape.fill(fill))
            .overlay(shape.strokeBorder(selected ? Theme.accent : (hovered ? Theme.lineStrong : Theme.line),
                                        lineWidth: selected ? 1.5 : 1))
            .overlay(
                shape.strokeBorder(LinearGradient(colors: [Color.white.opacity(0.07), .clear],
                                                  startPoint: .top, endPoint: UnitPoint(x: 0.5, y: 0.08)),
                                   lineWidth: 1)
                    .allowsHitTesting(false)
            )
            .shadow(color: hovered || selected ? Theme.accent.opacity(0.16) : .clear, radius: 18, y: 10)
    }
}

/// A Riven card: radius 20, `surface`, hairline border. Set `interactive` to lift it
/// 4pt on hover.
struct Card<Content: View>: View {
    var padding: CGFloat = Theme.Space.l
    var radius: CGFloat = Theme.Radius.card
    var interactive = false
    @ViewBuilder var content: Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovered = false

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .rivenSurface(radius: radius, hovered: interactive && isHovered)
            .offset(y: interactive && isHovered && !reduceMotion ? -4 : 0)
            .onHover { if interactive { isHovered = $0 } }
            .animation(reduceMotion ? nil : Theme.easeOut(Theme.medium), value: isHovered)
    }
}

/// A feature panel: radius 28.
struct Panel<Content: View>: View {
    var padding: CGFloat = Theme.Space.l
    @ViewBuilder var content: Content

    var body: some View {
        Card(padding: padding, radius: Theme.Radius.panel) { content }
    }
}

// MARK: - Chips, headings, stats

/// Mono uppercase capsule. `.accent` for live states, `.muted` for everything else.
struct Chip: View {
    enum Tone { case accent, muted, success, warning }

    let text: String
    var tone: Tone = .accent
    /// Draws a small status dot before the text.
    var dot = false

    private var foreground: Color {
        switch tone {
        case .accent: Theme.accent
        case .muted: Theme.muted
        case .success: Theme.success
        case .warning: Theme.amber
        }
    }

    private var background: Color {
        switch tone {
        case .accent: Theme.accentTint
        case .muted: Theme.surface2
        case .success: Theme.success.opacity(0.10)
        case .warning: Theme.amber.opacity(0.10)
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            if dot {
                Circle().fill(foreground).frame(width: 6, height: 6)
            }
            Text(text)
                .font(Theme.mono(10.5, .medium))
                .tracking(0.85)
                .textCase(.uppercase)
        }
        .foregroundStyle(foreground)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Capsule().fill(background))
        .fixedSize()
    }
}

/// A heading where exactly one word is Instrument Serif italic (design.md §3).
struct AccentHeading: View {
    let before: String
    let accent: String
    var after = ""
    var size: CGFloat = 28
    var weight: Font.Weight = .semibold

    var body: some View {
        (Text(before).font(Theme.sans(size, weight))
            + Text(accent).font(Theme.serif(size * 1.1)).foregroundColor(Theme.ink)
            + Text(after).font(Theme.sans(size, weight)))
            .tracking(-0.02 * size)
            .foregroundStyle(Theme.ink)
            .accessibilityAddTraits(.isHeader)
    }
}

/// A micro label above an accent heading, as at the top of every Riven section.
struct SectionHeader: View {
    var label: String?
    let before: String
    let accent: String
    var after = ""
    var size: CGFloat = 28
    var detail: String?

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.xs) {
            if let label {
                Text(label).microLabel()
            }
            AccentHeading(before: before, accent: accent, after: after, size: size)
            if let detail {
                Text(detail)
                    .font(Theme.sans(14))
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// A DM Mono number above a micro label.
struct Stat: View {
    let value: String
    let label: String
    var accent = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(Theme.mono(24, .medium))
                .monospacedDigit()
                .foregroundStyle(accent ? Theme.accent : Theme.ink)
            Text(label).microLabel()
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Inputs

/// A Riven text input: radius 12, `surface2`, hairline border that turns accent on focus.
struct RivenSearchField: View {
    let prompt: String
    @Binding var text: String

    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: Theme.Space.xs) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.faint)
                .accessibilityHidden(true)
            TextField(prompt, text: $text, prompt: Text(prompt).foregroundColor(Theme.faint))
                .textFieldStyle(.plain)
                .font(Theme.sans(13))
                .foregroundStyle(Theme.ink)
                .focused($isFocused)
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Theme.faint)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, Theme.Space.s)
        .frame(height: 32)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.input, style: .continuous).fill(Theme.surface2))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.input, style: .continuous)
            .strokeBorder(isFocused ? Theme.accent : Theme.line, lineWidth: 1))
    }
}

/// A pill segmented control: the active segment gets the accent tint, not a fill.
struct PillPicker<Value: Hashable>: View {
    let options: [(value: Value, title: String)]
    @Binding var selection: Value
    var accessibilityLabel: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options, id: \.value) { option in
                let isSelected = option.value == selection
                Button {
                    selection = option.value
                } label: {
                    Text(option.title)
                        .font(Theme.sans(12.5, .medium))
                        .foregroundStyle(isSelected ? Theme.accent : Theme.muted)
                        .padding(.horizontal, 12)
                        .frame(height: 26)
                        .background(Capsule().fill(isSelected ? Theme.accentTint : .clear))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(3)
        .background(Capsule().fill(Theme.surface))
        .overlay(Capsule().strokeBorder(Theme.line, lineWidth: 1))
        .animation(reduceMotion ? nil : Theme.easeInOut(Theme.fast), value: selection)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityLabel)
    }
}

// MARK: - Atmosphere

/// Film grain (design.md §8): a tiled noise texture at about 3% so large dark areas
/// don't look flat.
struct Grain: View {
    var opacity: Double = 1

    var body: some View {
        Image(nsImage: GrainTile.image)
            .resizable(resizingMode: .tile)
            .opacity(opacity)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

enum GrainTile {
    /// A 128 × 128 tile of faint light and dark speckles, identical on every launch.
    @MainActor static let image: NSImage = make(size: 128, seed: 11)

    static func make(size: Int, seed: UInt64) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()
        var rng = SeededGenerator(seed: seed)
        for y in 0..<size {
            for x in 0..<size {
                let roll = Double.random(in: 0..<1, using: &rng)
                guard roll < 0.30 else { continue }
                let light = roll < 0.13
                NSColor(white: light ? 1 : 0, alpha: light ? 0.035 : 0.05).setFill()
                NSRect(x: x, y: y, width: 1, height: 1).fill(using: .sourceOver)
            }
        }
        image.unlockFocus()
        return image
    }
}

/// The page background: `bg`, film grain, and optionally the view's one accent glow.
struct RivenBackground: View {
    var fill: Color = Theme.bg
    /// Where the single radial glow sits, in unit coordinates. `nil` for none.
    var glow: UnitPoint?
    var glowRadius: CGFloat = 420

    var body: some View {
        ZStack {
            fill
            if let glow {
                GeometryReader { geo in
                    RadialGradient(colors: [Theme.accentGlow, .clear], center: glow,
                                   startRadius: 0, endRadius: glowRadius)
                        .frame(width: geo.size.width, height: geo.size.height)
                }
            }
            Grain()
        }
        .ignoresSafeArea()
    }
}

/// A divider in `line`, one point tall.
struct Hairline: View {
    var body: some View {
        Rectangle().fill(Theme.line).frame(height: 1)
    }
}

// MARK: - Entrances

extension EnvironmentValues {
    /// Set by render tests, which capture a single frame: no entrance animations and
    /// no scroll views (which image rendering can't draw).
    @Entry var rivenStaticRender = false
}

/// A pane's scrolling column. Lays out without scrolling in render tests.
struct PaneScroll<Content: View>: View {
    @ViewBuilder var content: Content

    @Environment(\.rivenStaticRender) private var isStatic

    var body: some View {
        if isStatic {
            content
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .top)
                .clipped()
        } else {
            ScrollView { content }
                .scrollContentBackground(.hidden)
        }
    }
}

private struct Entrance: ViewModifier {
    let index: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.rivenStaticRender) private var isStatic
    @State private var hasAppeared = false

    func body(content: Content) -> some View {
        let shown = hasAppeared || isStatic
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown || reduceMotion ? 0 : 16)
            .onAppear {
                guard !hasAppeared else { return }
                // Fade and 16pt rise, staggered 60 ms (design.md §6). Reduce Motion: a short fade.
                let animation = reduceMotion
                    ? Animation.easeOut(duration: Theme.fast)
                    : Theme.easeOut(Theme.slow).delay(Double(index) * 0.06)
                withAnimation(animation) { hasAppeared = true }
            }
    }
}

extension View {
    /// Riven's entrance: fade and rise once when the view appears, staggered by `index`.
    func entrance(_ index: Int) -> some View {
        modifier(Entrance(index: index))
    }
}
