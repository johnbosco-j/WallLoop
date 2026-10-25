import SwiftUI

struct GeneralPane: View {
    @Bindable var settings: SettingsStore

    @State private var loginItem = LoginItem()
    @State private var displays = DisplayInfo.connected()

    var body: some View {
        Form {
            Section("Startup") {
                Toggle("Open at login", isOn: Binding(get: { loginItem.isOn }, set: { loginItem.setOn($0) }))
                if loginItem.needsApproval {
                    LabeledContent {
                        Button("Open Login Items…") { loginItem.openLoginItemsSettings() }
                    } label: {
                        Text("Allow WallLoop in System Settings to finish turning this on.")
                            .foregroundStyle(.secondary)
                    }
                }
                if let error = loginItem.errorMessage {
                    Text(error)
                        .font(.callout)
                        .foregroundStyle(.red)
                }
            }

            Section {
                Picker("Change wallpaper", selection: $settings.shuffleInterval) {
                    ForEach(ShuffleInterval.allCases) { Text($0.phrase).tag($0) }
                }
                Picker("Order", selection: $settings.playbackOrder) {
                    ForEach(PlaybackOrder.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                Toggle("Shuffle favorites only", isOn: $settings.favoritesOnly)
                Picker("Scaling", selection: $settings.fitMode) {
                    ForEach(FitMode.allCases) { Text($0.title).tag($0) }
                }
            } header: {
                Text("Playback")
            } footer: {
                if settings.favoritesOnly, settings.favorites.isEmpty {
                    Text("You have no favorites yet, so WallLoop plays all your videos.")
                        .foregroundStyle(.secondary)
                }
            }

            Section("Displays") {
                ForEach(displays) { display in
                    LabeledContent {
                        Text(display.resolution)
                            .monospacedDigit()
                    } label: {
                        Label {
                            Text(display.name)
                        } icon: {
                            Image(systemName: display.isBuiltIn ? "laptopcomputer" : "display")
                        }
                    }
                }
                Picker("Videos", selection: $settings.displayMode) {
                    ForEach(DisplayMode.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.radioGroup)
            }

            Section {
                Toggle("On battery power", isOn: $settings.pauseOnBattery)
                Toggle("When Low Power Mode is on", isOn: $settings.pauseInLowPowerMode)
                Toggle("When an app covers the desktop", isOn: $settings.pauseWhenCovered)
            } header: {
                Text("Pause Automatically")
            } footer: {
                Text("WallLoop always pauses while your Mac is locked or asleep, or while another user is using it.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .onAppear { loginItem.refresh() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            loginItem.refresh()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)) { _ in
            withAnimation(.smooth) { displays = DisplayInfo.connected() }
        }
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
