import SwiftUI

struct ContentView: View {
    @Environment(RadioPlayer.self) private var radio

    var body: some View {
        @Bindable var radio = radio

        VStack(spacing: 24) {
            AsyncImage(url: RadioPlayer.logoURL) { image in
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

            // Controls only this app's volume; the system output volume is untouched.
            HStack(spacing: 12) {
                Image(systemName: "speaker.fill")
                Slider(value: $radio.volume, in: 0...1)
                    .accessibilityLabel("Volume")
                Image(systemName: "speaker.wave.3.fill")
            }
            .foregroundStyle(.secondary)
            .frame(maxWidth: 280)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    ContentView()
        .environment(RadioPlayer())
}
