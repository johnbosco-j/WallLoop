import KeyboardShortcuts
import SwiftUI

struct ShortcutsPane: View {
    var body: some View {
        PaneScroll {
            VStack(alignment: .leading, spacing: Theme.Space.l) {
                SectionHeader(label: "Shortcuts", before: "Keys that work ", accent: "everywhere", after: ".",
                              detail: "Control your wallpaper from any app. No Accessibility permission needed.")

                SettingsCard(title: "Global shortcuts",
                             footer: "Click a shortcut and press new keys to change it, or press Delete to turn it off.") {
                    ForEach(Array(Shortcuts.all.enumerated()), id: \.element.name.rawValue) { index, shortcut in
                        if index > 0 { Hairline().padding(.leading, Theme.Space.l) }
                        SettingRow(title: shortcut.title, detail: nil) {
                            KeyboardShortcuts.Recorder(for: shortcut.name)
                                .accessibilityLabel(shortcut.title)
                        }
                    }
                }

                Button("Restore Defaults") { Shortcuts.restoreDefaults() }
                    .buttonStyle(.rivenSecondary)
            }
            .frame(maxWidth: 760, alignment: .leading)
            .padding(.horizontal, Theme.Space.xl)
            .padding(.top, 44)
            .padding(.bottom, Theme.Space.xl)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(RivenBackground())
    }
}
