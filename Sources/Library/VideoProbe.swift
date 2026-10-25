import AVFoundation
import VideoToolbox

/// Checks whether a video can play on this Mac's hardware decoder, and whether
/// it carries an alpha channel (HEVC with alpha).
enum VideoProbe {
    enum Result: Sendable, Equatable {
        case playable(hasAlpha: Bool)
        case unsupported(reason: String)
    }

    static func probe(_ url: URL) async -> Result {
        let asset = AVURLAsset(url: url)
        do {
            guard let track = try await asset.loadTracks(withMediaType: .video).first else {
                return .unsupported(reason: "Has no video track")
            }
            guard let format = try await track.load(.formatDescriptions).first else {
                return .unsupported(reason: "The video track can't be read")
            }
            let codec = CMFormatDescriptionGetMediaSubType(format)
            guard VTIsHardwareDecodeSupported(codec) else {
                return .unsupported(reason: "\(codecName(codec)) can't be hardware-decoded on this Mac")
            }
            let alpha = CMFormatDescriptionGetExtension(
                format, extensionKey: kCMFormatDescriptionExtension_ContainsAlphaChannel) as? NSNumber
            return .playable(hasAlpha: alpha?.boolValue ?? false)
        } catch {
            return .unsupported(reason: "Can't be opened")
        }
    }

    static func codecName(_ codec: FourCharCode) -> String {
        switch codec {
        case kCMVideoCodecType_H264: "H.264"
        case kCMVideoCodecType_HEVC, kCMVideoCodecType_HEVCWithAlpha: "HEVC"
        case kCMVideoCodecType_AV1: "AV1"
        case kCMVideoCodecType_VP9: "VP9"
        case kCMVideoCodecType_AppleProRes422, kCMVideoCodecType_AppleProRes4444,
             kCMVideoCodecType_AppleProRes422HQ, kCMVideoCodecType_AppleProRes422LT,
             kCMVideoCodecType_AppleProRes422Proxy, kCMVideoCodecType_AppleProRes4444XQ: "ProRes"
        default: fourCC(codec)
        }
    }

    private static func fourCC(_ code: FourCharCode) -> String {
        let bytes = [24, 16, 8, 0].map { UInt8((code >> $0) & 0xFF) }
        let text = String(decoding: bytes, as: UTF8.self).trimmingCharacters(in: .whitespaces)
        return text.isEmpty ? "This codec" : "The “\(text)” codec"
    }
}

/// Probes files and remembers the answers, keyed by path, modification date and
/// size, so rescanning a library only probes files that changed.
actor VideoProber {
    private struct Entry {
        let modified: Date?
        let size: Int?
        let result: VideoProbe.Result
    }

    private var cache: [String: Entry] = [:]

    func probe(_ file: ScannedFile) async -> VideoProbe.Result {
        if let entry = cache[file.url.path], entry.modified == file.modified, entry.size == file.size {
            return entry.result
        }
        let result = await VideoProbe.probe(file.url)
        cache[file.url.path] = Entry(modified: file.modified, size: file.size, result: result)
        return result
    }
}

/// A video file found while scanning a folder.
struct ScannedFile: Sendable, Hashable {
    let url: URL
    let modified: Date?
    let size: Int?
}
