import SwiftUI

struct AboutPane: View {
    private var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "Version \(short) (\(build))"
    }

    var body: some View {
        ZStack {
            Backdrop()

            VStack(spacing: 14) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 112, height: 112)
                Text("WallLoop")
                    .font(.largeTitle.weight(.semibold))
                Text(version)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Text("Live video wallpapers from your own videos.")
                    .font(.body)
                    .padding(.top, 2)

                Divider().padding(.vertical, 6)

                Label("No tracking. Your videos and settings stay on your Mac.", systemImage: "lock.shield")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Text("Made by John Bosco")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
            }
            .multilineTextAlignment(.center)
            .padding(36)
            .frame(maxWidth: 420)
            .glassSurface(cornerRadius: 32)
            .padding(32)
        }
    }
}
