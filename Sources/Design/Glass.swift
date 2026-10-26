import SwiftUI

// Floating glass, like Riven's nav capsule (design.md §7): Liquid Glass on macOS 26 and
// later; on macOS 14–15, `surface` at 72% over a blur with a hairline border.

extension View {
    /// A floating glass panel.
    @ViewBuilder
    func glassSurface(cornerRadius: CGFloat = Theme.Radius.card) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        if #available(macOS 26, *) {
            glassEffect(.regular.tint(Theme.surface.opacity(0.5)), in: shape)
                .overlay(shape.strokeBorder(Theme.line, lineWidth: 1))
        } else {
            background(Theme.surface.opacity(0.72), in: shape)
                .background(.ultraThinMaterial, in: shape)
                .overlay(shape.strokeBorder(Theme.line, lineWidth: 1))
        }
    }

    /// A small glass capsule, for badges and transport controls over thumbnails.
    @ViewBuilder
    func glassCapsule() -> some View {
        if #available(macOS 26, *) {
            glassEffect(.regular.tint(Theme.surface.opacity(0.5)), in: .capsule)
                .overlay(Capsule().strokeBorder(Theme.line, lineWidth: 1))
        } else {
            background(Theme.surface.opacity(0.72), in: Capsule())
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().strokeBorder(Theme.line, lineWidth: 1))
        }
    }
}
