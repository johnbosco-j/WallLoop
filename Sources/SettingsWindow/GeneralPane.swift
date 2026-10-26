import SwiftUI

struct GeneralPane: View {
    @Bindable var settings: SettingsStore

    @State private var loginItem = LoginItem()
    @State private var displays = DisplayInfo.connected()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        PaneScroll {
            VStack(alignment: .leading, spacing: Theme.Space.l) {
                SectionHeader(label: "General", before: "How WallLoop ", accent: "behaves", after: ".",
                              detail: "Startup, playback, displays and when to rest.")

                SettingsCard(title: "Startup") {
                    SettingRow(title: "Open at login",
                               detail: "Start WallLoop when you log in, through macOS Login Items.") {
                        Toggle("Open at login", isOn: Binding(get: { loginItem.isOn }, set: { loginItem.setOn($0) }))
                    }
                    if loginItem.needsApproval {
                        Hairline().padding(.leading, Theme.Space.l)
                        SettingRow(title: "Needs your approval",
                                   detail: "Allow WallLoop in System Settings to finish turning this on.") {
                            Button("Open Login Items…") { loginItem.openLoginItemsSettings() }
                                .buttonStyle(.riven(.secondary, size: .small))
                        }
                    }
                    if let error = loginItem.errorMessage {
                        Text(error)
                            .font(Theme.sans(12))
                            .foregroundStyle(Theme.danger)
                            .padding(.horizontal, Theme.Space.l)
                            .padding(.bottom, Theme.Space.m)
                    }
                }

                SettingsCard(title: "Playback") {
                    SettingRow(title: "Change wallpaper", detail: "How often WallLoop moves to the next video.") {
                        Picker("Change wallpaper", selection: $settings.shuffleInterval) {
                            ForEach(ShuffleInterval.allCases) { Text($0.phrase).tag($0) }
                        }
                        .pickerStyle(.menu)
                        .fixedSize()
                    }
                    Hairline().padding(.leading, Theme.Space.l)
                    SettingRow(title: "Order", detail: "Shuffle plays every video once before repeating.") {
                        PillPicker(options: PlaybackOrder.allCases.map { ($0, $0.title) },
                                   selection: $settings.playbackOrder, accessibilityLabel: "Order")
                    }
                    Hairline().padding(.leading, Theme.Space.l)
                    SettingRow(title: "Shuffle favorites only",
                               detail: settings.favoritesOnly && settings.favorites.isEmpty
                                   ? "You have no favorites yet, so WallLoop plays all your videos."
                                   : "Only play the videos you’ve hearted.") {
                        Toggle("Shuffle favorites only", isOn: $settings.favoritesOnly)
                    }
                    Hairline().padding(.leading, Theme.Space.l)
                    SettingRow(title: "Scaling", detail: "How each video fills its display.") {
                        Picker("Scaling", selection: $settings.fitMode) {
                            ForEach(FitMode.allCases) { Text($0.title).tag($0) }
                        }
                        .pickerStyle(.menu)
                        .fixedSize()
                    }
                }

                SettingsCard(title: "Displays") {
                    ForEach(displays) { display in
                        HStack(spacing: Theme.Space.s) {
                            Image(systemName: display.isBuiltIn ? "laptopcomputer" : "display")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(Theme.ink)
                                .frame(width: 34, height: 34)
                                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Theme.surface2))
                                .accessibilityHidden(true)
                            Text(display.name)
                                .font(Theme.sans(14, .medium))
                                .foregroundStyle(Theme.ink)
                            Spacer()
                            Text(display.resolution)
                                .font(Theme.mono(12))
                                .foregroundStyle(Theme.faint)
                        }
                        .padding(.horizontal, Theme.Space.l)
                        .padding(.vertical, Theme.Space.s)
                        .accessibilityElement(children: .combine)
                        Hairline().padding(.leading, Theme.Space.l)
                    }
                    SettingRow(title: "Videos", detail: "With more than one display.") {
                        PillPicker(options: DisplayMode.allCases.map { ($0, $0 == .sameOnAll ? "Same on all" : "One per display") },
                                   selection: $settings.displayMode, accessibilityLabel: "Videos on each display")
                    }
                }

                SettingsCard(title: "Pause automatically",
                             footer: "WallLoop always pauses while your Mac is locked or asleep, or while another user is using it.") {
                    SettingRow(title: "On battery power", detail: "Save energy when you’re unplugged.") {
                        Toggle("On battery power", isOn: $settings.pauseOnBattery)
                    }
                    Hairline().padding(.leading, Theme.Space.l)
                    SettingRow(title: "When Low Power Mode is on", detail: nil) {
                        Toggle("When Low Power Mode is on", isOn: $settings.pauseInLowPowerMode)
                    }
                    Hairline().padding(.leading, Theme.Space.l)
                    SettingRow(title: "When an app covers the desktop",
                               detail: "Full-screen apps or windows over every display.") {
                        Toggle("When an app covers the desktop", isOn: $settings.pauseWhenCovered)
                    }
                }
            }
            .frame(maxWidth: 760, alignment: .leading)
            .padding(.horizontal, Theme.Space.xl)
            .padding(.top, 44)
            .padding(.bottom, Theme.Space.xl)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(RivenBackground())
        .toggleStyle(.switch)
        .tint(Theme.accent)
        .onAppear { loginItem.refresh() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            loginItem.refresh()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)) { _ in
            withAnimation(reduceMotion ? nil : Theme.easeInOut()) { displays = DisplayInfo.connected() }
        }
    }
}

/// A Riven card holding rows of settings under a micro label.
struct SettingsCard<Content: View>: View {
    let title: String
    var footer: String?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.xs) {
            Card(padding: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(title)
                        .microLabel(Theme.muted)
                        .padding(.horizontal, Theme.Space.l)
                        .padding(.top, Theme.Space.m)
                        .padding(.bottom, Theme.Space.xxs)
                    content
                }
                .padding(.bottom, Theme.Space.xxs)
            }
            if let footer {
                Text(footer)
                    .font(Theme.sans(12))
                    .foregroundStyle(Theme.faint)
                    .padding(.horizontal, Theme.Space.xs)
            }
        }
    }
}

/// One setting: a title and helper text on the left, its control on the right.
struct SettingRow<Control: View>: View {
    let title: String
    let detail: String?
    @ViewBuilder var control: Control

    var body: some View {
        HStack(alignment: .center, spacing: Theme.Space.m) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(Theme.sans(14, .medium))
                    .foregroundStyle(Theme.ink)
                if let detail {
                    Text(detail)
                        .font(Theme.sans(12))
                        .foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: Theme.Space.m)
            control
                .labelsHidden()
        }
        .padding(.horizontal, Theme.Space.l)
        .padding(.vertical, 14)
    }
}

/// A connected display, as shown in General › Displays.
struct DisplayInfo: Identifiable, Equatable {
    let id: CGDirectDisplayID
    let name: String
    let resolution: String
    let isBuiltIn: Bool

    @MainActor
    static func connected() -> [DisplayInfo] {
        NSScreen.screens.compactMap { screen in
            guard let id = screen.displayID else { return nil }
            let size = screen.frame.size
            return DisplayInfo(id: id, name: screen.localizedName,
                               resolution: "\(Int(size.width)) × \(Int(size.height))",
                               isBuiltIn: CGDisplayIsBuiltin(id) != 0)
        }
    }
}
