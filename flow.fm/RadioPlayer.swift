import AVFoundation
import MediaPlayer
import Observation

/// Plays the SomaFM DEF CON Radio Icecast stream and publishes the current track title.
@Observable
final class RadioPlayer {
    /// 128k AAC mirror taken from https://somafm.com/defcon130.pls
    static let streamURL = URL(string: "https://ice2.somafm.com/defcon-128-aac")!
    /// Recent-tracks feed; the first entry is the song currently on air.
    static let songsURL = URL(string: "https://somafm.com/songs/defcon.json")!
    static let logoURL = URL(string: "https://api.somafm.com/logos/512/defcon512.png")!

    private(set) var isPlaying = false
    private(set) var track: Track?

    var nowPlaying: String? {
        track.map { "\($0.artist) – \($0.title)" }
    }

    @ObservationIgnored private let player = AVPlayer()
    @ObservationIgnored private let nowPlayingCenter = NowPlayingCenter()
    @ObservationIgnored private var artwork: MPMediaItemArtwork?
    @ObservationIgnored private var nowPlayingTask: Task<Void, Never>?
    @ObservationIgnored private var interruptionTasks: [Task<Void, Never>] = []
    /// True when the system, not the user, stopped playback (phone call, Siri, another app).
    @ObservationIgnored private var wasInterrupted = false

    init() {
        nowPlayingCenter.configureCommands(
            play: { [weak self] in self?.play() },
            stop: { [weak self] in self?.stop() },
            toggle: { [weak self] in self?.togglePlayback() }
        )
        observeInterruptions()
    }

    func togglePlayback() {
        isPlaying ? stop() : play()
    }

    func play() {
        wasInterrupted = false
        activateAudioSession()

        // Live streams can't resume where they paused, so always start a fresh item at the live edge.
        player.replaceCurrentItem(with: AVPlayerItem(url: Self.streamURL))
        player.play()
        isPlaying = true
        publishNowPlaying()

        nowPlayingTask?.cancel()
        nowPlayingTask = Task { await pollNowPlaying() }
        if artwork == nil {
            Task { await loadArtwork() }
        }
    }

    func stop() {
        player.pause()
        player.replaceCurrentItem(with: nil)
        isPlaying = false
        nowPlayingTask?.cancel()
        nowPlayingTask = nil
        publishNowPlaying()
    }

    private func publishNowPlaying() {
        nowPlayingCenter.update(isPlaying: isPlaying, track: track, artwork: artwork)
    }

    private func activateAudioSession() {
        #if os(iOS) || os(visionOS)
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Audio session error: \(error)")
        }
        #endif
    }

    /// Stops when the system takes the audio session, and restarts if the system
    /// recommends resuming afterwards. macOS has no audio session interruptions.
    private func observeInterruptions() {
        #if os(iOS) || os(visionOS)
        let session = AVAudioSession.sharedInstance()

        interruptionTasks.append(Task { [weak self] in
            for await notification in NotificationCenter.default.notifications(
                named: AVAudioSession.didBecomeInactiveNotification, object: session
            ) {
                guard let context = notification.userInfo?[AVAudioSession.deactivationContextKey]
                        as? AVAudioSession.DeactivationContext,
                      context.source == .system,
                      let self, self.isPlaying else { continue }
                self.stop()
                self.wasInterrupted = true
            }
        })

        interruptionTasks.append(Task { [weak self] in
            for await notification in NotificationCenter.default.notifications(
                named: AVAudioSession.resumptionRecommendationNotification, object: session
            ) {
                guard let context = notification.userInfo?[AVAudioSession.resumptionContextKey]
                        as? AVAudioSession.ResumptionContext,
                      context.recommendation == .shouldResume,
                      let self, self.wasInterrupted else { continue }
                self.play()
            }
        })
        #endif
    }

    /// AVPlayer doesn't surface the stream's ICY `StreamTitle`, so poll SomaFM's song feed instead.
    /// 30 seconds keeps the title reasonably fresh without hammering a listener-supported service.
    private func pollNowPlaying() async {
        while !Task.isCancelled {
            do {
                let (data, _) = try await URLSession.shared.data(from: Self.songsURL)
                if let latest = try JSONDecoder().decode(SongHistory.self, from: data).songs.first,
                   latest != track {
                    track = latest
                    publishNowPlaying()
                }
            } catch {
                print("Now playing fetch failed: \(error)")
            }
            try? await Task.sleep(for: .seconds(30))
        }
    }

    private func loadArtwork() async {
        guard let (data, _) = try? await URLSession.shared.data(from: Self.logoURL),
              let artwork = NowPlayingCenter.artwork(from: data) else { return }
        self.artwork = artwork
        publishNowPlaying()
    }
}

struct Track: Decodable, Equatable {
    let title: String
    let artist: String
}

/// Shape of https://somafm.com/songs/defcon.json (only the fields we use).
private struct SongHistory: Decodable {
    let songs: [Track]
}
