import SwiftUI

/// WallLoop's mark: Loopy, a happy play button, inside a rose orbit ring with a
/// travelling dot — Riven's orbit motif (design.md §5, §9) carrying WallLoop's own accent.
///
/// Drawn on the 1024 × 1024 macOS icon grid and scaled to fit, so the same code renders
/// the app icon layers, the DMG artwork and the in-app logo (`scripts/render-brand.sh`).
struct BrandMark: View {
    enum Part: CaseIterable { case glow, orbit, buddy, face }

    var parts: Set<Part> = Set(Part.allCases)

    var body: some View {
        Canvas { context, size in
            let u = min(size.width, size.height) / 1024
            let origin = CGPoint(x: (size.width - 1024 * u) / 2, y: (size.height - 1024 * u) / 2)
            func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: origin.x + x * u, y: origin.y + y * u) }
            func oval(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> Path {
                Path(ellipseIn: CGRect(x: p(x, y).x - w / 2 * u, y: p(x, y).y - h / 2 * u, width: w * u, height: h * u))
            }

            if parts.contains(.glow) {
                // The one accent glow: a radial wash fading to transparent (design.md §2).
                context.fill(oval(512, 520, 860, 860), with: .radialGradient(
                    Gradient(colors: [Theme.accent.opacity(0.34), Theme.accent.opacity(0.10), .clear]),
                    center: p(512, 520), startRadius: 0, endRadius: 430 * u))
                // Film grain (design.md §8) keeps the glow from banding into rings.
                var rng = SeededGenerator(seed: 7)
                for _ in 0..<9000 {
                    let x = CGFloat.random(in: 120...904, using: &rng), y = CGFloat.random(in: 120...904, using: &rng)
                    let light = Bool.random(using: &rng)
                    context.fill(Path(CGRect(x: p(x, y).x, y: p(x, y).y, width: 2 * u, height: 2 * u)),
                                 with: .color(light ? .white.opacity(0.035) : .black.opacity(0.06)))
                }
            }
            if parts.contains(.orbit) {
                let ring = oval(512, 512, 700, 700)
                context.stroke(ring, with: .color(Theme.accent), lineWidth: 30 * u)
                // The travelling sphere, at about two o'clock.
                let angle = Angle.degrees(-38).radians
                let dot = (512 + 350 * cos(angle), 512 + 350 * sin(angle))
                context.fill(oval(dot.0, dot.1, 104, 104), with: .color(Theme.bg))
                context.fill(oval(dot.0, dot.1, 76, 76), with: .color(Theme.accent))
            }
            // Loopy is drawn a little larger than the grid suggests so it still reads at 16 px.
            var buddyContext = context
            buddyContext.translateBy(x: p(520, 512).x, y: p(520, 512).y)
            buddyContext.scaleBy(x: 1.16, y: 1.16)
            buddyContext.translateBy(x: -p(520, 512).x, y: -p(520, 512).y)
            if parts.contains(.buddy) {
                buddyContext.fill(Self.buddy(p: p, u: u), with: .color(Theme.ink))
            }
            if parts.contains(.face) {
                let context = buddyContext
                for x in [474.0, 566.0] {
                    context.fill(oval(x, 482, 50, 68), with: .color(Theme.bg2))
                    context.fill(oval(x + 9, 468, 16, 18), with: .color(.white))   // catch-light
                }
                for x in [440.0, 604.0] {
                    context.fill(oval(x, 562, 70, 40), with: .color(Theme.accent.opacity(0.85)))
                }
                var smile = Path()
                smile.move(to: p(492, 550))
                smile.addQuadCurve(to: p(548, 550), control: p(520, 586))
                context.stroke(smile, with: .color(Theme.bg2), style: StrokeStyle(lineWidth: 16 * u, lineCap: .round))
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }

    /// A rounded play triangle, nudged right so it looks centred.
    private static func buddy(p: (CGFloat, CGFloat) -> CGPoint, u: CGFloat) -> Path {
        let a = p(388, 300), b = p(752, 512), c = p(388, 724)
        let radius = 88 * u
        var path = Path()
        path.move(to: CGPoint(x: a.x, y: (a.y + c.y) / 2))
        path.addArc(tangent1End: a, tangent2End: b, radius: radius)
        path.addArc(tangent1End: b, tangent2End: c, radius: radius)
        path.addArc(tangent1End: c, tangent2End: a, radius: radius)
        path.closeSubpath()
        return path
    }
}

/// A tiny deterministic random generator, so the grain is identical on every render.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed &* 0x9E37_79B9_7F4A_7C15 | 1 }
    mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}

/// The full app icon, flat: Riven's dark surface tile with Loopy. Used in the app's UI
/// and as the icon on macOS 14–15 (macOS 26+ uses the layered Liquid Glass version).
struct BrandIcon: View {
    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let tile = side * 824 / 1024
            let shape = RoundedRectangle(cornerRadius: tile * 0.2237, style: .continuous)
            ZStack {
                shape.fill(Theme.surface)
                BrandMark().frame(width: tile, height: tile).clipShape(shape)
                // Riven elevation: a hairline border and a faint top highlight, no heavy shadow.
                shape.strokeBorder(Theme.lineStrong, lineWidth: max(1, side / 256))
            }
            .frame(width: tile, height: tile)
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}
