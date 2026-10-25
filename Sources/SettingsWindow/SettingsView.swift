import SwiftUI

struct SettingsView: View {
    let model: AppModel
    @Bindable var navigation: SettingsNavigation

    var body: some View {
        NavigationSplitView {
            List(SettingsPane.allCases, selection: $navigation.selection) { pane in
                Label(pane.title, systemImage: pane.symbol)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 260)
        } detail: {
            switch navigation.selection ?? .library {
            case .library: LibraryPane(model: model)
            case .general: GeneralPane(settings: model.settings)
            case .about: AboutPane()
            }
        }
        .navigationTitle((navigation.selection ?? .library).title)
        .frame(minWidth: 680, minHeight: 460)
    }
}
