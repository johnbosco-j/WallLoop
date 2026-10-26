import SwiftUI

/// Where the About pane's links point. Update these if the project moves.
enum AppLinks {
    static let repository = URL(string: "https://github.com/johnbosco-j/WallLoop")!
    static let license = repository.appending(path: "blob/main/LICENSE")
    static let releaseNotes = repository.appending(path: "blob/main/CHANGELOG.md")
    static let riven = URL(string: "https://rivendevs.in")!
    static let sparkle = URL(string: "https://sparkle-project.org")!
    static let keyboardShortcuts = URL(string: "https://github.com/sindresorhus/KeyboardShortcuts")!
    static let instrumentSans = URL(string: "https://fonts.google.com/specimen/Instrument+Sans")!
    static let instrumentSerif = URL(string: "https://fonts.google.com/specimen/Instrument+Serif")!
    static let dmMono = URL(string: "https://fonts.google.com/specimen/DM+Mono")!
}

/// WallLoop's own small product page: the mark, what it is, who made it, updates and credits.
struct AboutPane: View {
    @Bindable private var updater = Updater.shared

    var body: some View {
        PaneScroll {
            VStack(spacing: Theme.Space.l) {
                AboutHero(version: AboutCopy.version(Bundle.main.infoDictionary))
                    .entrance(0)

                Card {
                    VStack(alignment: .leading, spacing: Theme.Space.s) {
                        Text("Updates").microLabel(Theme.muted)
                        HStack(spacing: Theme.Space.m) {
                            Button("Check for Updates…") { updater.checkForUpdates() }
                                .buttonStyle(.rivenPrimary)
                                .disabled(!updater.canCheckForUpdates)
                            Toggle("Check automatically", isOn: $updater.automaticallyChecksForUpdates)
                                .toggleStyle(.switch)
                                .disabled(!updater.isConfigured)
                                .font(Theme.sans(13))
                                .foregroundStyle(Theme.muted)
                            Spacer(minLength: 0)
                        }
                        if !updater.isConfigured {
                            Text("Updates are turned off in this build.")
                                .font(Theme.sans(12))
                                .foregroundStyle(Theme.faint)
                        }
                    }
                }
                .entrance(1)

                Card {
                    VStack(alignment: .leading, spacing: Theme.Space.s) {
                        Text("Made by").microLabel(Theme.muted)
                        Text(AboutCopy.credit)
                            .font(Theme.sans(15, .medium))
                            .foregroundStyle(Theme.ink)
                        Text(AboutCopy.studio)
                            .font(Theme.mono(11))
                            .foregroundStyle(Theme.faint)
                        Text("Privacy: no tracking, no accounts. Your videos and settings stay on your Mac.")
                            .font(Theme.sans(13))
                            .foregroundStyle(Theme.muted)
                            .padding(.top, Theme.Space.xxs)
                        HStack(spacing: Theme.Space.xs) {
                            ExternalLink("Release notes", AppLinks.releaseNotes)
                            ExternalLink("License", AppLinks.license)
                            ExternalLink("Riven", AppLinks.riven)
                        }
                        .padding(.top, Theme.Space.xs)
                    }
                }
                .entrance(2)

                Card {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Acknowledgements").microLabel(Theme.muted)
                        credit("Sparkle", "Software updates", "MIT License", AppLinks.sparkle)
                        credit("KeyboardShortcuts", "Global shortcuts, by Sindre Sorhus", "MIT License",
                               AppLinks.keyboardShortcuts)
                        credit("Instrument Sans", "Interface type", "SIL Open Font License", AppLinks.instrumentSans)
                        credit("Instrument Serif", "Accent type", "SIL Open Font License", AppLinks.instrumentSerif)
                        credit("DM Mono", "Labels and numbers", "SIL Open Font License", AppLinks.dmMono)
                    }
                }
                .entrance(3)
            }
            .frame(maxWidth: 620)
            .padding(.horizontal, Theme.Space.xl)
            .padding(.top, 44)
            .padding(.bottom, Theme.Space.xl)
            .frame(maxWidth: .infinity)
        }
        .background(RivenBackground(glow: UnitPoint(x: 0.5, y: 0.12), glowRadius: 380))
        .tint(Theme.accent)
    }

    private func credit(_ name: String, _ purpose: String, _ license: String, _ url: URL) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Link(destination: url) {
                Text("\(name) ↗")
                    .font(Theme.sans(13, .medium))
                    .foregroundStyle(Theme.ink)
            }
            .help("\(name) (opens in your browser)")
            Text(purpose)
                .font(Theme.sans(13))
                .foregroundStyle(Theme.muted)
            Spacer()
            Text(license)
                .font(Theme.mono(10.5))
                .foregroundStyle(Theme.faint)
        }
    }
}

/// The top of the About pane: icon, name, tagline, version and the Riven lockup.
struct AboutHero: View {
    let version: String

    var body: some View {
        VStack(spacing: Theme.Space.s) {
            BrandIcon()
                .frame(width: 136, height: 136)
                .accessibilityHidden(true)
            Text("A Riven product").microLabel()
            Text("WallLoop")
                .font(Theme.sans(48, .semibold))
                .tracking(-0.035 * 48)
                .foregroundStyle(Theme.ink)
                .accessibilityAddTraits(.isHeader)
            AccentHeading(before: "Your videos, ", accent: "alive", after: " on the desktop.", size: 20, weight: .regular)
            HStack(spacing: Theme.Space.xs) {
                Chip(text: version, tone: .muted)
                Text("WallLoop — by Riven")
                    .font(Theme.sans(13))
                    .foregroundStyle(Theme.muted)
            }
            .padding(.top, Theme.Space.xxs)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
    }
}

/// About-pane strings, kept in one place (and tested).
enum AboutCopy {
    static let credit = "Carved by Johnbosco J Elanjikal, founder of Riven"
    static let studio = "Built by RivenDevs"

    static func version(_ info: [String: Any]?) -> String {
        let short = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "v\(short) · build \(build)"
    }
}

/// A secondary button that opens a web page, marked with ↗.
struct ExternalLink: View {
    let title: String
    let url: URL

    init(_ title: String, _ url: URL) {
        self.title = title
        self.url = url
    }

    @Environment(\.openURL) private var openURL

    var body: some View {
        Button("\(title) ↗") { openURL(url) }
            .buttonStyle(.riven(.secondary, size: .small))
            .help("\(title) (opens in your browser)")
    }
}
