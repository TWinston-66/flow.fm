import SwiftUI

@main struct MyApp: App {
    /// Owned by the app so there's exactly one player registered with the system's remote commands.
    @State private var radio = RadioPlayer()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(radio)
        }
    }
}
