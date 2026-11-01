import SwiftUI

/// Controls only this app's volume; the system output volume is untouched.
struct VolumeSlider: View {
    @Environment(RadioPlayer.self) private var radio

    var body: some View {
        @Bindable var radio = radio

        HStack(spacing: 12) {
            Image(systemName: "speaker.fill")
            Slider(value: $radio.volume, in: 0...1)
                .accessibilityLabel("Volume")
            Image(systemName: "speaker.wave.3.fill")
        }
        .foregroundStyle(.secondary)
    }
}

struct QualityPicker: View {
    @Environment(RadioPlayer.self) private var radio

    var body: some View {
        @Bindable var radio = radio

        Picker("Quality", selection: $radio.quality) {
            ForEach(StreamQuality.allCases) { quality in
                Text(quality.label).tag(quality)
            }
        }
        .pickerStyle(.menu)
        .fixedSize()
    }
}

/// SomaFM is listener-supported; this opens their donation page in the browser.
struct SupportSomaFMLink: View {
    static let supportURL = URL(string: "https://somafm.com/support/")!

    var body: some View {
        Link(destination: Self.supportURL) {
            Label("Support SomaFM", systemImage: "heart.fill")
        }
    }
}
