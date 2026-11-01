import SwiftUI

@main struct MyApp: App {
    static let mainWindowID = "main"

    /// Owned by the app so there's exactly one player registered with the system's remote commands.
    @State private var radio = RadioPlayer()

    var body: some Scene {
        #if os(macOS)
        // A single window: "Open flow.fm" brings this one back rather than opening duplicates.
        Window("flow.fm", id: Self.mainWindowID) {
            ContentView()
                .environment(radio)
                .frame(minWidth: 360, minHeight: 480)
                .hidesDockIconWhenClosed()
        }
        .defaultSize(width: 420, height: 760)

        // Stays available after the main window is closed, so the stream can keep playing in the background.
        MenuBarExtra("DEF CON Radio", systemImage: radio.isPlaying ? "dot.radiowaves.left.and.right" : "radio") {
            MenuBarPlayerView()
                .environment(radio)
        }
        .menuBarExtraStyle(.window)
        #else
        WindowGroup(id: Self.mainWindowID) {
            ContentView()
                .environment(radio)
        }
        #endif
    }
}

#if os(macOS)
private extension View {
    /// Shows the Dock icon while the main window is open, and turns flow.fm into a menu-bar-only
    /// app (no Dock icon or app-switcher entry) once it's closed.
    func hidesDockIconWhenClosed() -> some View {
        onAppear { NSApplication.shared.setActivationPolicy(.regular) }
            .onDisappear { NSApplication.shared.setActivationPolicy(.accessory) }
    }
}
#endif
