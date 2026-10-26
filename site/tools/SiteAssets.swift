// Renders the website's images from the app's own brand code (Sources/Design), so the
// site, the app icon and the DMG always match. Run site/tools/render-assets.sh.
import AppKit
import SwiftUI

@main
struct SiteAssets {
    @MainActor
    static func main() throws {
        let root = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? ".")
        Theme.registerFonts(in: root.appendingPathComponent("Sources/Resources/Fonts"))
        let out = root.appendingPathComponent("site/assets")
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)

        try write(BrandIcon(), width: 512, height: 512, to: out.appendingPathComponent("icon-512.png"))
        try write(BrandIcon(), width: 1024, height: 1024, to: out.appendingPathComponent("icon-1024.png"))
        // iOS masks touch icons itself, so this one is full-bleed and opaque.
        try write(ZStack { Theme.surface; BrandMark() }, width: 180, height: 180,
                  to: out.appendingPathComponent("apple-touch-icon.png"), opaque: true)
        try write(OpenGraphCard(), width: 1200, height: 630, to: out.appendingPathComponent("og.png"), opaque: true)
        print("Rendered site assets into \(out.path)")
    }

    @MainActor
    static func write(_ view: some View, width: CGFloat, height: CGFloat, to url: URL, opaque: Bool = false) throws {
        let renderer = ImageRenderer(content: view.frame(width: width, height: height))
        renderer.scale = 1
        renderer.isOpaque = opaque
        guard let image = renderer.cgImage,
              let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
        else { throw CocoaError(.fileWriteUnknown) }
        try png.write(to: url)
    }
}

/// 1200 × 630 social card: Riven black, one rose glow, hairline orbit rings around Loopy.
struct OpenGraphCard: View {
    var body: some View {
        ZStack(alignment: .leading) {
            Theme.bg
            Circle()
                .fill(RadialGradient(colors: [Theme.accent.opacity(0.22), Theme.accent.opacity(0.06), .clear],
                                     center: .center, startRadius: 0, endRadius: 360))
                .frame(width: 720, height: 720)
                .position(x: 905, y: 315)
            ForEach([300.0, 420.0, 540.0], id: \.self) { size in
                Circle()
                    .stroke(Theme.accent.opacity(size == 420 ? 0.45 : 0.22), lineWidth: 1.2)
                    .frame(width: size, height: size)
                    .position(x: 905, y: 315)
            }
            Circle().fill(Theme.accent).frame(width: 12, height: 12).position(x: 905 + 210 * cos(-0.6), y: 315 + 210 * sin(-0.6))
            BrandIcon().frame(width: 300, height: 300).position(x: 905, y: 315)

            VStack(alignment: .leading, spacing: 0) {
                Text("MACOS APP · BY RIVEN")
                    .font(Theme.mono(20, .medium)).tracking(2).foregroundStyle(Theme.accent)
                Text("WallLoop")
                    .font(.custom("Instrument Serif", size: 132)).foregroundStyle(Theme.ink)
                    .padding(.top, 18)
                Text("Your videos, \(Text("alive").font(Theme.serif(48)))\non your desktop.")
                    .font(Theme.sans(42, .semibold))
                    .foregroundStyle(Theme.ink)
                    .lineSpacing(2)
                    .padding(.top, 8)
                Spacer()
                Text("wallloop.rivendevs.in")
                    .font(Theme.mono(20)).foregroundStyle(Theme.faint)
            }
            .padding(.leading, 80)
            .padding(.vertical, 72)
        }
    }
}
