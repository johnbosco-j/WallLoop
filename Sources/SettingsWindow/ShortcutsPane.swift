import KeyboardShortcuts
import SwiftUI

struct ShortcutsPane: View {
    var body: some View {
        Form {
            Section {
                ForEach(Shortcuts.all, id: \.name.rawValue) { shortcut in
                    KeyboardShortcuts.Recorder(shortcut.title, name: shortcut.name)
                }
            } header: {
                Text("Global Shortcuts")
            } footer: {
                Text("These work in any app. Click a shortcut and press new keys to change it, or press Delete to turn it off.")
                    .foregroundStyle(.secondary)
            }

            Section {
                HStack {
                    Spacer()
                    Button("Restore Defaults") { Shortcuts.restoreDefaults() }
                }
            }
        }
        .formStyle(.grouped)
    }
}
