// Renders a placeholder app icon set into Sources/Resources/Assets.xcassets/AppIcon.appiconset.
// Replace the PNGs with your final artwork (same file names and sizes) when it's ready.
//
//   swift scripts/make-placeholder-icon.swift
import AppKit

let setDir = URL(fileURLWithPath: "Sources/Resources/Assets.xcassets/AppIcon.appiconset")
try FileManager.default.createDirectory(at: setDir, withIntermediateDirectories: true)

func render(pixels: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let s = CGFloat(pixels) / 1024

    // macOS icon grid: an 824 pt rounded square centred on a 1024 pt canvas.
    let tile = NSRect(x: 100 * s, y: 100 * s, width: 824 * s, height: 824 * s)
    let path = NSBezierPath(roundedRect: tile, xRadius: 185 * s, yRadius: 185 * s)
    NSGradient(colors: [NSColor(red: 0.30, green: 0.50, blue: 1.00, alpha: 1),
                        NSColor(red: 0.56, green: 0.36, blue: 0.96, alpha: 1),
                        NSColor(red: 0.98, green: 0.44, blue: 0.60, alpha: 1)])!
        .draw(in: path, angle: -55)

    let config = NSImage.SymbolConfiguration(pointSize: 380 * s, weight: .semibold)
        .applying(.init(hierarchicalColor: .white))
    if let symbol = NSImage(systemSymbolName: "play.rectangle.on.rectangle.fill",
                            accessibilityDescription: nil)?.withSymbolConfiguration(config) {
        let size = symbol.size
        symbol.draw(in: NSRect(x: (CGFloat(pixels) - size.width) / 2,
                               y: (CGFloat(pixels) - size.height) / 2,
                               width: size.width, height: size.height))
    }
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

// macOS needs 16, 32, 128, 256 and 512 pt, each at 1x and 2x.
var images: [[String: String]] = []
for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let name = "icon_\(points)x\(points)\(scale == 2 ? "@2x" : "").png"
        try render(pixels: points * scale).write(to: setDir.appendingPathComponent(name))
        images.append(["idiom": "mac", "size": "\(points)x\(points)", "scale": "\(scale)x", "filename": name])
    }
}
let contents: [String: Any] = ["images": images, "info": ["version": 1, "author": "xcode"]]
try JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
    .write(to: setDir.appendingPathComponent("Contents.json"))
print("Wrote \(images.count) icons to \(setDir.path)")
