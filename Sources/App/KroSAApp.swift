import SwiftUI

@main
struct KroSAApp: App {
    init() {
        // Prepare the app-owned Documents directory used as the GTA data root.
        _ = try? GameFilesDirectory.prepare()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
        }
    }
}
