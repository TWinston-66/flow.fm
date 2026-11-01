import SwiftUI

struct ContentView: View {
    @Environment(RadioPlayer.self) private var radio

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                AsyncImage(url: RadioPlayer.logoURL) { image in
                    image.resizable().scaledToFit()
                } placeholder: {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.quaternary)
                }
                // Square, so the placeholder keeps its size while the logo loads (or if offline).
                .aspectRatio(1, contentMode: .fit)
                .frame(maxWidth: 256)
                .clipShape(.rect(cornerRadius: 16))
                .accessibilityHidden(true)

                VStack(spacing: 6) {
                    Text("DEF CON Radio")
                        .font(.title.bold())
                    Text("Music for Hacking · SomaFM")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Text(radio.errorMessage ?? radio.nowPlaying ?? (radio.isPlaying ? "Connecting…" : " "))
                    .font(.headline)
                    .foregroundStyle(radio.errorMessage == nil ? .primary : Color.red)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(minHeight: 44)

                Button {
                    radio.togglePlayback()
                } label: {
                    Image(systemName: radio.isPlaying ? "stop.fill" : "play.fill")
                        .font(.largeTitle)
                        .frame(width: 72, height: 72)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.circle)
                .accessibilityLabel(radio.isPlaying ? "Stop" : "Play")

                VolumeSlider()
                    .frame(maxWidth: 280)

                VStack(spacing: 12) {
                    QualityPicker()
                    SupportSomaFMLink()
                        .font(.subheadline)
                }

                RecentTracksView(tracks: Array(radio.recentTracks.dropFirst()))
                    .frame(maxWidth: 480)
            }
            .padding(32)
            .frame(maxWidth: .infinity)
        }
        .task {
            // Show history (and what's on air) before the user presses play.
            await radio.refreshTracks()
        }
    }
}

/// Songs that played before the current one, most recent first.
private struct RecentTracksView: View {
    let tracks: [Track]

    var body: some View {
        if !tracks.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Recently Played")
                    .font(.title3.bold())

                ForEach(tracks) { track in
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(track.title)
                                .font(.body)
                            Text(track.album.isEmpty ? track.artist : "\(track.artist) · \(track.album)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                        Text(track.playedAt, style: .time)
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }
}

#Preview {
    ContentView()
        .environment(RadioPlayer())
}
