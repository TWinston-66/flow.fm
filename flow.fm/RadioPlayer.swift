import AVFoundation
import MediaPlayer
import Observation

/// Plays the SomaFM DEF CON Radio Icecast stream and publishes the current track title.
@Observable
final class RadioPlayer {
    /// 128k AAC playlist; lists several Icecast mirrors for the same stream.
    static let playlistURL = URL(string: "https://somafm.com/defcon130.pls")!
    /// Used when the playlist itself can't be fetched.
    static let fallbackMirrors = ["ice2", "ice5", "ice6"].map {
        URL(string: "https://\($0).somafm.com/defcon-128-aac")!
    }
    /// Recent-tracks feed; the first entry is the song currently on air.
    static let songsURL = URL(string: "https://somafm.com/songs/defcon.json")!
    static let logoURL = URL(string: "https://api.somafm.com/logos/512/defcon512.png")!

    /// How long a mirror gets to start producing audio before we try the next one.
    private static let connectTimeout: Duration = .seconds(10)
    private static let volumeKey = "volume"

    private(set) var isPlaying = false
    private(set) var track: Track?
    private(set) var errorMessage: String?

    /// App-only volume (0...1), independent of the system output volume. Persisted across launches.
    var volume: Float = UserDefaults.standard.object(forKey: RadioPlayer.volumeKey) as? Float ?? 1 {
        didSet {
            player.volume = volume
            UserDefaults.standard.set(volume, forKey: Self.volumeKey)
        }
    }

    var nowPlaying: String? {
        track.map { "\($0.artist) – \($0.title)" }
    }

    @ObservationIgnored private let player = AVPlayer()
    @ObservationIgnored private let nowPlayingCenter = NowPlayingCenter()
    @ObservationIgnored private var mirrors: [URL]
    @ObservationIgnored private var artwork: MPMediaItemArtwork?
    @ObservationIgnored private var streamTask: Task<Void, Never>?
    @ObservationIgnored private var nowPlayingTask: Task<Void, Never>?
    @ObservationIgnored private var interruptionTasks: [Task<Void, Never>] = []
    /// True when the system, not the user, stopped playback (phone call, Siri, another app).
    @ObservationIgnored private var wasInterrupted = false

    /// - Parameter mirrors: Stream URLs to use instead of resolving `playlistURL` (empty = resolve on first play).
    init(mirrors: [URL] = []) {
        self.mirrors = mirrors
        player.volume = volume
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
        errorMessage = nil
        activateAudioSession()
        isPlaying = true
        publishNowPlaying()

        streamTask?.cancel()
        streamTask = Task { await runStream() }
        nowPlayingTask?.cancel()
        nowPlayingTask = Task { await pollNowPlaying() }
        if artwork == nil {
            Task { await loadArtwork() }
        }
    }

    func stop() {
        streamTask?.cancel()
        streamTask = nil
        player.pause()
        player.currentItem?.asset.cancelLoading()
        player.replaceCurrentItem(with: nil)
        isPlaying = false
        nowPlayingTask?.cancel()
        nowPlayingTask = nil
        publishNowPlaying()
    }

    private func publishNowPlaying() {
        nowPlayingCenter.update(isPlaying: isPlaying, track: track, artwork: artwork)
    }

    // MARK: - Connecting and failover

    /// Connects to the first mirror that starts producing audio, and moves on to the next
    /// mirror whenever a connection hangs, fails, or drops mid-stream. Gives up after every
    /// mirror has failed in a row. Live streams can't resume in place, so each attempt uses a
    /// fresh `AVPlayerItem` at the live edge.
    private func runStream() async {
        if mirrors.isEmpty {
            mirrors = await Self.resolveMirrors()
        }

        var index = 0
        var failuresInARow = 0
        while !Task.isCancelled {
            let item = AVPlayerItem(url: mirrors[index])
            player.replaceCurrentItem(with: item)
            player.play()

            if await waitUntilPlaying(item) {
                failuresInARow = 0
                await waitUntilStreamEnds(item)
            } else {
                failuresInARow += 1
            }
            // A hung connection otherwise blocks the player from loading the next item.
            item.asset.cancelLoading()
            guard !Task.isCancelled else { return }

            if failuresInARow >= mirrors.count {
                stop()
                errorMessage = "Couldn't reach DEF CON Radio. Check your connection and try again."
                return
            }
            index = (index + 1) % mirrors.count
            // Brief pause so a flapping connection doesn't hammer SomaFM's servers.
            try? await Task.sleep(for: .seconds(1))
        }
    }

    /// Returns true once audio is actually flowing, false if the item fails or times out.
    private func waitUntilPlaying(_ item: AVPlayerItem) async -> Bool {
        let deadline = ContinuousClock.now + Self.connectTimeout
        while ContinuousClock.now < deadline, !Task.isCancelled {
            if item.status == .failed { return false }
            if item.status == .readyToPlay, player.timeControlStatus == .playing { return true }
            try? await Task.sleep(for: .milliseconds(250))
        }
        return false
    }

    /// Suspends until the server closes the stream or playback fails (or the task is cancelled).
    private func waitUntilStreamEnds(_ item: AVPlayerItem) async {
        await withTaskGroup(of: Void.self) { group in
            for name in [AVPlayerItem.didPlayToEndTimeNotification,
                         AVPlayerItem.failedToPlayToEndTimeNotification] {
                group.addTask {
                    for await _ in NotificationCenter.default.notifications(named: name, object: item) {
                        return
                    }
                }
            }
            await group.next()
            group.cancelAll()
        }
    }

    /// Fetches the `.pls` playlist for the current mirror list, falling back to known mirrors.
    private static func resolveMirrors() async -> [URL] {
        guard let (data, _) = try? await URLSession.shared.data(from: playlistURL),
              let text = String(data: data, encoding: .utf8) else { return fallbackMirrors }
        let urls = parsePlaylist(text)
        return urls.isEmpty ? fallbackMirrors : urls
    }

    /// Extracts stream URLs from `FileN=` lines of a PLS playlist, in order.
    nonisolated static func parsePlaylist(_ text: String) -> [URL] {
        text.split(whereSeparator: \.isNewline).compactMap { line in
            guard line.lowercased().hasPrefix("file"),
                  let equals = line.firstIndex(of: "=") else { return nil }
            let value = line[line.index(after: equals)...].trimmingCharacters(in: .whitespaces)
            return URL(string: value)
        }
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
