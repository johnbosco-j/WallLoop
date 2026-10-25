import SwiftUI

// Liquid Glass on macOS 26 and later, with the closest earlier look on macOS 14–15.
// Standard controls (sidebars, toolbars, menus) adopt Liquid Glass on their own;
// these helpers are only for WallLoop's custom surfaces.

extension View {
    /// A floating glass panel.
    @ViewBuilder
    func glassSurface(cornerRadius: CGFloat = 24) -> some View {
        if #available(macOS 26, *) {
            glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
        } else {
            background(.regularMaterial, in: .rect(cornerRadius: cornerRadius))
        }
    }

    /// A small glass capsule, for badges over thumbnails.
    @ViewBuilder
    func glassCapsule() -> some View {
        if #available(macOS 26, *) {
            glassEffect(.regular, in: .capsule)
        } else {
            background(.ultraThinMaterial, in: .capsule)
        }
    }

    @ViewBuilder
    func glassButtonStyle(prominent: Bool = false) -> some View {
        if #available(macOS 26, *) {
            if prominent { buttonStyle(.glassProminent) } else { buttonStyle(.glass) }
        } else {
            if prominent { buttonStyle(.borderedProminent) } else { buttonStyle(.bordered) }
        }
    }
}

/// The soft gradient behind glass panels, so the glass has something to refract.
struct Backdrop: View {
    var body: some View {
        LinearGradient(
            colors: [Color(red: 0.36, green: 0.55, blue: 1.0),
                     Color(red: 0.55, green: 0.38, blue: 0.95),
                     Color(red: 0.95, green: 0.45, blue: 0.62)],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
        .opacity(0.55)
        .ignoresSafeArea()
    }
}
