import SwiftUI

/// Where the About pane's links point. Update these if the project moves.
enum AppLinks {
    static let repository = URL(string: "https://github.com/johnbosco-j/WallLoop")!
    static let license = repository.appending(path: "blob/main/LICENSE")
    static let releaseNotes = repository.appending(path: "blob/main/CHANGELOG.md")
    static let sparkle = URL(string: "https://sparkle-project.org")!
    static let keyboardShortcuts = URL(string: "https://github.com/sindresorhus/KeyboardShortcuts")!
}

struct AboutPane: View {
    @Bindable private var updater = Updater.shared

    private var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "Version \(short) (\(build))"
    }

    var body: some View {
        ZStack {
            Backdrop()

            ScrollView {
                VStack(spacing: 14) {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .frame(width: 104, height: 104)
                        .accessibilityHidden(true)
                    Text("WallLoop")
                        .font(.largeTitle.weight(.semibold))
                    Text(version)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                    Text("Live video wallpapers from your own videos.")
                        .font(.body)
                        .padding(.top, 2)

                    VStack(spacing: 8) {
                        Button("Check for Updates…") { updater.checkForUpdates() }
                            .glassButtonStyle(prominent: true)
                            .controlSize(.large)
                            .disabled(!updater.canCheckForUpdates)
                        Toggle("Automatically check for updates", isOn: $updater.automaticallyChecksForUpdates)
                            .toggleStyle(.checkbox)
                            .disabled(!updater.isConfigured)
                        if !updater.isConfigured {
                            Text("Updates are turned off in this build.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.top, 6)

                    Divider().padding(.vertical, 6)

                    Label("Privacy: no tracking, no accounts. Your videos and settings stay on your Mac.",
                          systemImage: "lock.shield")
                        .font(.callout)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 18) {
                        Link("Release Notes", destination: AppLinks.releaseNotes)
                        Link("License", destination: AppLinks.license)
                        Link("Source Code", destination: AppLinks.repository)
                    }
                    .font(.callout)

                    VStack(spacing: 4) {
                        Text("Acknowledgements")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.secondary)
                        credit("Sparkle", "software updates", AppLinks.sparkle)
                        credit("KeyboardShortcuts", "global shortcuts, by Sindre Sorhus", AppLinks.keyboardShortcuts)
                    }
                    .padding(.top, 4)

                    Text("Made by John Bosco. Released under the MIT License.")
                        .font(.footnote)
                        .foregroundStyle(.tertiary)
                        .padding(.top, 2)
                }
                .multilineTextAlignment(.center)
                .padding(36)
                .frame(maxWidth: 440)
                .glassSurface(cornerRadius: 32)
                .padding(32)
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func credit(_ name: String, _ purpose: String, _ url: URL) -> some View {
        HStack(spacing: 4) {
            Link(name, destination: url)
            Text("— \(purpose) (MIT License)")
                .foregroundStyle(.secondary)
        }
        .font(.footnote)
    }
}
