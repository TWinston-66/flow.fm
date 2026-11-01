import AVFoundation
import Observation

/// Plays the SomaFM DEF CON Radio Icecast stream and publishes the current track title.
@Observable
final class RadioPlayer {
    /// 128k AAC mirror taken from https://somafm.com/defcon130.pls
    static let streamURL = URL(string: "https://ice2.somafm.com/defcon-128-aac")!
    /// Recent-tracks feed; the first entry is the song currently on air.
    static let songsURL = URL(string: "https://somafm.com/songs/defcon.json")!

    private(set) var isPlaying = false
    private(set) var nowPlaying: String?

    @ObservationIgnored private let player = AVPlayer()
    @ObservationIgnored private var nowPlayingTask: Task<Void, Never>?

    func togglePlayback() {
        isPlaying ? stop() : play()
    }

    func play() {
        configureAudioSession()

        // Live streams can't resume where they paused, so always start a fresh item at the live edge.
        player.replaceCurrentItem(with: AVPlayerItem(url: Self.streamURL))
        player.play()
        isPlaying = true

        nowPlayingTask?.cancel()
        nowPlayingTask = Task { await pollNowPlaying() }
    }

    func stop() {
        player.pause()
        player.replaceCurrentItem(with: nil)
        isPlaying = false
        nowPlayingTask?.cancel()
        nowPlayingTask = nil
    }

    private func configureAudioSession() {
        #if os(iOS) || os(visionOS)
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Audio session error: \(error)")
        }
        #endif
    }

    /// AVPlayer doesn't surface the stream's ICY `StreamTitle`, so poll SomaFM's song feed instead.
    /// 30 seconds keeps the title reasonably fresh without hammering a listener-supported service.
    private func pollNowPlaying() async {
        while !Task.isCancelled {
            do {
                let (data, _) = try await URLSession.shared.data(from: Self.songsURL)
                if let song = try JSONDecoder().decode(SongHistory.self, from: data).songs.first {
                    nowPlaying = "\(song.artist) – \(song.title)"
                }
            } catch {
                print("Now playing fetch failed: \(error)")
            }
            try? await Task.sleep(for: .seconds(30))
        }
    }
}

/// Shape of https://somafm.com/songs/defcon.json (only the fields we use).
private struct SongHistory: Decodable {
    struct Song: Decodable {
        let title: String
        let artist: String
    }
    let songs: [Song]
}
