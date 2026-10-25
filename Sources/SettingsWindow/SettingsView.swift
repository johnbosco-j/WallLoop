import SwiftUI

struct SettingsView: View {
    let model: AppModel
    @Bindable var navigation: SettingsNavigation

    private var pane: SettingsPane { navigation.selection ?? .library }

    var body: some View {
        NavigationSplitView {
            List(SettingsPane.allCases, selection: $navigation.selection) { pane in
                Label(pane.title, systemImage: pane.symbol)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 260)
        } detail: {
            switch pane {
            case .library: LibraryPane(model: model)
            case .general: GeneralPane(settings: model.settings)
            case .shortcuts: ShortcutsPane()
            case .about: AboutPane()
            }
        }
        .navigationTitle(pane.title)
        .frame(minWidth: 880, minHeight: 520)
    }
}
