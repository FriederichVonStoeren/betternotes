import SwiftUI

@main
struct BetterNotesApp: App {
    var body: some Scene {
        WindowGroup {
            // Install test only: proves the CI-built .ipa can be sideloaded.
            VStack(spacing: 12) {
                Text("betternotes").font(.largeTitle).bold()
                Text("install.ok")
                Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "")
                    .foregroundStyle(.secondary)
            }
        }
    }
}
