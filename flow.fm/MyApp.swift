import SwiftUI

@main struct MyApp: App {
    static let mainWindowID = "main"

    /// Owned by the app so there's exactly one player registered with the system's remote commands.
    @State private var radio = RadioPlayer()

    var body: some Scene {
        WindowGroup(id: Self.mainWindowID) {
            ContentView()
                .environment(radio)
        }

        #if os(macOS)
        // Stays available after the main window is closed, so the stream can keep playing in the background.
        MenuBarExtra("DEF CON Radio", systemImage: radio.isPlaying ? "dot.radiowaves.left.and.right" : "radio") {
            MenuBarPlayerView()
                .environment(radio)
        }
        .menuBarExtraStyle(.window)
        #endif
    }
}
