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
