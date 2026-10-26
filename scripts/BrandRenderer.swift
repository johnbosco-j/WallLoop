// Renders WallLoop's brand artwork from Sources/Design/BrandMark.swift, so the app icon,
// DMG artwork and in-app logo always match. Run scripts/render-brand.sh rather than this file.
import AppKit
import SwiftUI

@main
struct BrandRenderer {
    @MainActor
    static func main() throws {
        let root = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? ".")
        let resources = root.appendingPathComponent("Sources/Resources")
        let brandDir = root.appendingPathComponent("build/brand")
        try FileManager.default.createDirectory(at: brandDir, withIntermediateDirectories: true)

        // 1. Liquid Glass icon (macOS 26+): one layer per part, composed by the system.
        let iconDir = resources.appendingPathComponent("AppIcon.icon")
        let assets = iconDir.appendingPathComponent("Assets")
        try FileManager.default.createDirectory(at: assets, withIntermediateDirectories: true)
        if let old = try? FileManager.default.contentsOfDirectory(at: assets, includingPropertiesForKeys: nil) {
            old.forEach { try? FileManager.default.removeItem(at: $0) }
        }
        for (name, part) in [("glow", BrandMark.Part.glow), ("orbit", .orbit), ("buddy", .buddy), ("face", .face)] {
            try write(BrandMark(parts: [part]), size: 1024, to: assets.appendingPathComponent("\(name).png"))
        }
        try iconJSON.write(to: iconDir.appendingPathComponent("icon.json"), atomically: true, encoding: .utf8)

        // 2. Previews and the flat icon used by the DMG and website. (Xcode renders the
        //    .icns for macOS 14–15 from AppIcon.icon itself, glass shading included.)
        try write(BrandIcon(), size: 1024, to: brandDir.appendingPathComponent("icon-1024.png"))

        // 3. DMG window background at 1x and 2x; scripts/dmg/ combines them into one HiDPI TIFF.
        Theme.registerFonts(in: root.appendingPathComponent("Sources/Resources/Fonts"))
        let dmgDir = root.appendingPathComponent("scripts/dmg")
        try FileManager.default.createDirectory(at: dmgDir, withIntermediateDirectories: true)
        for scale in [1, 2] {
            let renderer = ImageRenderer(content: DMGBackground())
            renderer.scale = CGFloat(scale)
            guard let image = renderer.cgImage,
                  let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
            else { throw CocoaError(.fileWriteUnknown) }
            try png.write(to: brandDir.appendingPathComponent("dmg-background\(scale == 2 ? "@2x" : "").png"))
        }
        print("Rendered brand artwork into \(resources.path) and \(brandDir.path)")
    }

    @MainActor
    static func write(_ view: some View, size: CGFloat, to url: URL) throws {
        let renderer = ImageRenderer(content: view.frame(width: size, height: size))
        renderer.scale = 1
        renderer.isOpaque = false
        guard let image = renderer.cgImage,
              let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
        else { throw CocoaError(.fileWriteUnknown) }
        try png.write(to: url)
    }

    /// Icon Composer document, top layer first: Loopy's face (no glass, so its colours stay
    /// crisp) over the glass buddy, the glass orbit ring, then the soft glow, all on Riven's
    /// dark surface.
    static let iconJSON = """
    {
      "fill" : {
        "solid" : "srgb:0.07843,0.07843,0.08235,1.00000"
      },
      "groups" : [
        {
          "layers" : [
            { "glass" : false, "hidden" : false, "image-name" : "face.png", "name" : "face" },
            { "glass" : true, "hidden" : false, "image-name" : "buddy.png", "name" : "buddy" }
          ],
          "shadow" : { "kind" : "neutral", "opacity" : 0.5 },
          "translucency" : { "enabled" : true, "value" : 0.2 }
        },
        {
          "layers" : [
            { "glass" : true, "hidden" : false, "image-name" : "orbit.png", "name" : "orbit" }
          ],
          "shadow" : { "kind" : "neutral", "opacity" : 0.4 },
          "translucency" : { "enabled" : true, "value" : 0.3 }
        },
        {
          "layers" : [
            { "glass" : false, "hidden" : false, "image-name" : "glow.png", "name" : "glow" }
          ]
        }
      ],
      "supported-platforms" : {
        "squares" : [ "macOS" ]
      }
    }

    """
}

/// The DMG window: Riven's dark studio, one rose glow behind the app, and an orbit arc
/// carrying a travelling sphere from WallLoop to Applications. Finder places the icons at
/// (170, 205) and (490, 205) on this 660 × 420 canvas; see scripts/dmg/settings.py.
struct DMGBackground: View {
    static let size = CGSize(width: 660, height: 420)
    static let app = CGPoint(x: 170, y: 205)
    static let applications = CGPoint(x: 490, y: 205)

    var body: some View {
        ZStack(alignment: .topLeading) {
            Theme.bg
            RadialGradient(colors: [Theme.accent.opacity(0.17), Theme.accent.opacity(0.05), .clear],
                           center: UnitPoint(x: Self.app.x / Self.size.width, y: Self.app.y / Self.size.height),
                           startRadius: 0, endRadius: 210)
            Canvas { context, _ in
                // Faint orbit rings around the app, Riven's hero motif in miniature.
                for radius in [96.0, 132.0] {
                    context.stroke(Path(ellipseIn: CGRect(x: Self.app.x - radius, y: Self.app.y - radius,
                                                          width: radius * 2, height: radius * 2)),
                                   with: .color(Theme.line), lineWidth: 1)
                }
                // The drag path: an arc from the app to Applications.
                let start = CGPoint(x: 252, y: 178), end = CGPoint(x: 410, y: 178)
                let control = CGPoint(x: 331, y: 118)
                var arc = Path()
                arc.move(to: start)
                arc.addQuadCurve(to: end, control: control)
                context.stroke(arc, with: .color(Theme.lineStrong),
                               style: StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [1, 6]))
                var head = Path()
                head.move(to: CGPoint(x: end.x - 11, y: end.y - 9))
                head.addLine(to: end)
                head.addLine(to: CGPoint(x: end.x - 13, y: end.y + 3))
                context.stroke(head, with: .color(Theme.muted),
                               style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                // The travelling sphere, about two-thirds of the way along.
                let t = 0.64
                let sphere = CGPoint(x: (1 - t) * (1 - t) * start.x + 2 * (1 - t) * t * control.x + t * t * end.x,
                                     y: (1 - t) * (1 - t) * start.y + 2 * (1 - t) * t * control.y + t * t * end.y)
                context.fill(Path(ellipseIn: CGRect(x: sphere.x - 5, y: sphere.y - 5, width: 10, height: 10)),
                             with: .color(Theme.accent))
                // Film grain (design.md §8).
                var rng = SeededGenerator(seed: 42)
                for _ in 0..<5200 {
                    let x = CGFloat.random(in: 0...Self.size.width, using: &rng)
                    let y = CGFloat.random(in: 0...Self.size.height, using: &rng)
                    let light = Bool.random(using: &rng)
                    context.fill(Path(CGRect(x: x, y: y, width: 1, height: 1)),
                                 with: .color(light ? .white.opacity(0.05) : .black.opacity(0.25)))
                }
                // Mid-grey chips behind the icon names: Finder draws names black in light mode
                // and white in dark mode, and both stay readable on this tone.
                for center in [Self.app, Self.applications] {
                    let plate = CGRect(x: center.x - 52, y: center.y + 69, width: 104, height: 22)
                    context.fill(Path(roundedRect: plate, cornerRadius: 11), with: .color(Color(hex: 0x77757A)))
                }
            }

            Text("WALLLOOP — BY RIVEN")
                .font(Theme.mono(10, .medium)).tracking(1).foregroundStyle(Theme.faint)
                .position(x: 330, y: 30)
            HStack(alignment: .firstTextBaseline, spacing: 7) {
                Text("Drag WallLoop into").font(Theme.sans(22, .semibold))
                Text("Applications").font(Theme.serif(26))
            }
            .foregroundStyle(Theme.ink)
                .position(x: 330, y: 62)
            Text("CARVED BY JOHNBOSCO J ELANJIKAL, FOUNDER OF RIVEN  ·  BUILT BY RIVENDEVS")
                .font(Theme.mono(9, .medium)).tracking(0.8).foregroundStyle(Theme.faint)
                .position(x: 330, y: 392)
        }
        .frame(width: Self.size.width, height: Self.size.height)
    }
}
