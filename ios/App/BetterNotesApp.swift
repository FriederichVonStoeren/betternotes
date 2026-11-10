import SwiftUI

@main
struct BetterNotesApp: App {
    var body: some Scene {
        WindowGroup {
            SpikeView().ignoresSafeArea()
        }
    }
}

/// Milestone (b): the app is only the drawing spike.
private struct SpikeView: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> SpikeViewController {
        SpikeViewController()
    }

    func updateUIViewController(_ controller: SpikeViewController, context: Context) {}
}
