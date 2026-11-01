import SwiftUI

struct ContentView: View {
    @State private var radio = RadioPlayer()

    private let logoURL = URL(string: "https://api.somafm.com/logos/512/defcon512.png")

    var body: some View {
        VStack(spacing: 24) {
            AsyncImage(url: logoURL) { image in
                image.resizable().scaledToFit()
            } placeholder: {
                RoundedRectangle(cornerRadius: 16)
                    .fill(.quaternary)
            }
            .frame(maxWidth: 256, maxHeight: 256)
            .clipShape(.rect(cornerRadius: 16))
            .accessibilityHidden(true)

            VStack(spacing: 6) {
                Text("DEF CON Radio")
                    .font(.title.bold())
                Text("Music for Hacking · SomaFM")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Text(radio.nowPlaying ?? (radio.isPlaying ? "Connecting…" : " "))
                .font(.headline)
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
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    ContentView()
}
