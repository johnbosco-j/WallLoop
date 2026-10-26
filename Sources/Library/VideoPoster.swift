import AVFoundation
import CoreGraphics

/// Picks a representative still from a video for thumbnails and the lock screen.
///
/// Many wallpaper videos fade in from black, so a frame from the first second is often
/// empty. This takes a frame about a quarter of the way in, and if that's nearly black,
/// tries the middle.
enum VideoPoster {
    static func image(of video: URL, maxSize: CGSize) async -> CGImage? {
        let asset = AVURLAsset(url: video)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = maxSize

        let duration = (try? await asset.load(.duration)).map(CMTimeGetSeconds) ?? 0
        var fallback: CGImage?
        for time in candidateTimes(duration: duration) {
            guard let image = try? await generator.image(at: CMTime(seconds: time, preferredTimescale: 600)).image
            else { continue }
            if !isNearlyBlack(image) { return image }
            fallback = fallback ?? image
        }
        return fallback
    }

    /// Seconds to try, in order. Short or unknown durations fall back to the start.
    static func candidateTimes(duration: Double) -> [Double] {
        guard duration.isFinite, duration > 0.5 else { return [0] }
        let last = max(0, duration - 0.1)
        return [min(max(duration * 0.25, 1), 8, last), duration * 0.5].map { min($0, last) }
    }

    /// Whether the image's average brightness is below about 5%.
    static func isNearlyBlack(_ image: CGImage) -> Bool {
        let side = 8
        var pixels = [UInt8](repeating: 0, count: side * side * 4)
        guard let context = CGContext(data: &pixels, width: side, height: side, bitsPerComponent: 8,
                                      bytesPerRow: side * 4, space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return false }
        context.interpolationQuality = .medium
        context.draw(image, in: CGRect(x: 0, y: 0, width: side, height: side))
        var total = 0
        for i in stride(from: 0, to: pixels.count, by: 4) {
            total += Int(pixels[i]) + Int(pixels[i + 1]) + Int(pixels[i + 2])
        }
        return Double(total) / Double(side * side * 3 * 255) < 0.05
    }
}
