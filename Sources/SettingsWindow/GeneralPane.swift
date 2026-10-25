import SwiftUI

struct GeneralPane: View {
    @Bindable var settings: SettingsStore

    var body: some View {
        Form {
            Section("Playback") {
                Picker("Change wallpaper", selection: $settings.shuffleInterval) {
                    ForEach(ShuffleInterval.allCases) { Text($0.phrase).tag($0) }
                }
                Picker("Order", selection: $settings.playbackOrder) {
                    ForEach(PlaybackOrder.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                Picker("Scaling", selection: $settings.fitMode) {
                    ForEach(FitMode.allCases) { Text($0.title).tag($0) }
                }
            }

            Section("Displays") {
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
                Text("WallLoop always pauses while your Mac is locked or asleep.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}
