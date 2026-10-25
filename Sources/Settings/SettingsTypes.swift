import Foundation

/// How often the wallpaper changes on its own.
enum ShuffleInterval: String, CaseIterable, Identifiable, Sendable {
    case fiveMinutes, fifteenMinutes, thirtyMinutes, oneHour, threeHours, daily, never

    var id: Self { self }

    /// `nil` means the wallpaper only changes when you ask.
    var seconds: TimeInterval? {
        switch self {
        case .fiveMinutes: 5 * 60
        case .fifteenMinutes: 15 * 60
        case .thirtyMinutes: 30 * 60
        case .oneHour: 60 * 60
        case .threeHours: 3 * 60 * 60
        case .daily: 24 * 60 * 60
        case .never: nil
        }
    }

    var title: String {
        switch self {
        case .fiveMinutes: "5 Minutes"
        case .fifteenMinutes: "15 Minutes"
        case .thirtyMinutes: "30 Minutes"
        case .oneHour: "1 Hour"
        case .threeHours: "3 Hours"
        case .daily: "Daily"
        case .never: "Never"
        }
    }

    /// The title as a phrase, for "Change wallpaper: Every 5 minutes".
    var phrase: String {
        switch self {
        case .daily: "Every day"
        case .never: "Never"
        default: "Every \(title.lowercased())"
        }
    }
}

enum PlaybackOrder: String, CaseIterable, Identifiable, Sendable {
    case shuffle, inOrder

    var id: Self { self }

    var title: String {
        switch self {
        case .shuffle: "Shuffle"
        case .inOrder: "In Order"
        }
    }
}

/// How a video is scaled to a display. Names follow the system's own wallpaper settings.
enum FitMode: String, CaseIterable, Identifiable, Sendable {
    case fill, fit, stretch

    var id: Self { self }

    var title: String {
        switch self {
        case .fill: "Fill Screen"
        case .fit: "Fit to Screen"
        case .stretch: "Stretch to Fill Screen"
        }
    }
}

enum DisplayMode: String, CaseIterable, Identifiable, Sendable {
    case sameOnAll, perDisplay

    var id: Self { self }

    var title: String {
        switch self {
        case .sameOnAll: "Same on All Displays"
        case .perDisplay: "Different on Each Display"
        }
    }
}
