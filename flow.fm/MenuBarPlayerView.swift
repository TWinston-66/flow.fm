#if os(macOS)
import SwiftUI

/// Compact player shown from the Mac menu bar, so the stream can be controlled without the main window.
struct MenuBarPlayerView: View {
    @Environment(RadioPlayer.self) private var radio
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                AsyncImage(url: RadioPlayer.logoURL) { image in
                    image.resizable().scaledToFit()
                } placeholder: {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.quaternary)
                }
                .frame(width: 48, height: 48)
                .clipShape(.rect(cornerRadius: 8))
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text("DEF CON Radio")
                        .font(.headline)
                    Text(radio.errorMessage ?? radio.nowPlaying ?? (radio.isPlaying ? "Connecting…" : "SomaFM"))
                        .font(.subheadline)
                        .foregroundStyle(radio.errorMessage == nil ? .secondary : Color.red)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)

                Button {
                    radio.togglePlayback()
                } label: {
                    Image(systemName: radio.isPlaying ? "stop.fill" : "play.fill")
                        .font(.title2)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.circle)
                .accessibilityLabel(radio.isPlaying ? "Stop" : "Play")
            }

            VolumeSlider()

            HStack {
                QualityPicker()
                    .labelsHidden()
                Spacer()
                SupportSomaFMLink()
                    .fixedSize()
            }

            Divider()

            HStack {
                Button("Open flow.fm") {
                    openWindow(id: MyApp.mainWindowID)
                    NSApplication.shared.activate()
                }
                Spacer()
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
            }
        }
        .padding(16)
        .frame(width: 320)
        .task {
            // The panel may be opened without the main window ever appearing.
            await radio.refreshTracks()
        }
    }
}

#Preview {
    MenuBarPlayerView()
        .environment(RadioPlayer())
}
#endif
