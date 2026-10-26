import SwiftUI

struct SettingsView: View {
    let model: AppModel
    @Bindable var navigation: SettingsNavigation

    var body: some View {
        SettingsContent(model: model, selection: $navigation.selection)
    }
}

/// The window's content: Riven's sidebar and the selected pane.
struct SettingsContent: View {
    let model: any PlaybackModel
    @Binding var selection: SettingsPane?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var pane: SettingsPane { selection ?? .library }

    var body: some View {
        HStack(spacing: 0) {
            SettingsSidebar(selection: $selection, model: model)
                .frame(width: 232)
            Rectangle().fill(Theme.line).frame(width: 1)
            Group {
                switch pane {
                case .library: LibraryPane(model: model)
                case .general: GeneralPane(settings: model.settings)
                case .shortcuts: ShortcutsPane()
                case .about: AboutPane()
                }
            }
            .id(pane)
            .transition(.opacity)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .animation(reduceMotion ? nil : Theme.easeInOut(Theme.medium), value: pane)
        .background(Theme.bg)
        .foregroundStyle(Theme.ink)
        .tint(Theme.accent)
        .environment(\.colorScheme, .dark)
        .frame(minWidth: 980, minHeight: 620)
    }
}

// MARK: - Sidebar

struct SettingsSidebar: View {
    @Binding var selection: SettingsPane?
    let model: any PlaybackModel

    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Lockup()
                .padding(.top, 50)
                .padding(.horizontal, 20)

            Text("Settings")
                .microLabel()
                .padding(.top, 36)
                .padding(.bottom, 10)
                .padding(.horizontal, 22)

            VStack(spacing: 4) {
                ForEach(SettingsPane.allCases) { pane in
                    SidebarRow(pane: pane, isSelected: (selection ?? .library) == pane) {
                        selection = pane
                    }
                }
            }
            .padding(.horizontal, 12)
            .focusable()
            .focused($isFocused)
            .focusEffectDisabled()
            .onKeyPress(.upArrow) { move(-1) }
            .onKeyPress(.downArrow) { move(1) }

            Spacer(minLength: 24)

            SidebarNowPlaying(model: model)
                .padding(.horizontal, 12)

            Text("WallLoop \(Self.version) · Riven")
                .microLabel()
                .padding(.horizontal, 22)
                .padding(.top, 14)
                .padding(.bottom, 18)
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .background(RivenBackground(fill: Theme.bg2))
    }

    private func move(_ step: Int) -> KeyPress.Result {
        let panes = SettingsPane.allCases
        let index = panes.firstIndex(of: selection ?? .library) ?? 0
        selection = panes[(index + step + panes.count) % panes.count]
        return .handled
    }

    static var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev"
    }
}

/// The product lockup: icon, name and "by Riven".
struct Lockup: View {
    var body: some View {
        HStack(spacing: 10) {
            BrandIcon()
                .frame(width: 42, height: 42)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text("WallLoop")
                    .font(Theme.sans(17, .semibold))
                    .tracking(-0.3)
                    .foregroundStyle(Theme.ink)
                Text("By Riven")
                    .microLabel()
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("WallLoop, by Riven")
    }
}

private struct SidebarRow: View {
    let pane: SettingsPane
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: pane.symbol)
                    .font(.system(size: 13.5, weight: .medium))
                    .frame(width: 18)
                Text(pane.title)
                    .font(Theme.sans(14, .medium))
                Spacer(minLength: 0)
            }
            .foregroundStyle(isSelected ? Theme.accent : (isHovered ? Theme.ink : Theme.muted))
            .padding(.horizontal, 12)
            .frame(height: 36)
            .background(Capsule().fill(isSelected ? Theme.accentTint : (isHovered ? Theme.surface : .clear)))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(reduceMotion ? nil : Theme.easeOut(Theme.fast), value: isHovered)
        .accessibilityLabel(pane.title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// A small live-status card at the bottom of the sidebar.
private struct SidebarNowPlaying: View {
    let model: any PlaybackModel

    var body: some View {
        if let video = model.nowPlaying.first {
            VStack(alignment: .leading, spacing: 8) {
                if let reason = model.pauseReason {
                    Chip(text: "Paused", tone: .muted, dot: true)
                    Text(reason.title)
                        .font(Theme.mono(10.5))
                        .foregroundStyle(Theme.faint)
                } else if model.isPaused {
                    Chip(text: "Paused", tone: .muted, dot: true)
                } else {
                    Chip(text: "Live", tone: .success, dot: true)
                }
                Text(video.deletingPathExtension().lastPathComponent)
                    .font(Theme.sans(13, .medium))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .rivenSurface(radius: Theme.Radius.card)
            .accessibilityElement(children: .combine)
        }
    }
}
