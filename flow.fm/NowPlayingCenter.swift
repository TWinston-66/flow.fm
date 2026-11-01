import MediaPlayer
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

/// Publishes the stream to the system Now Playing UI (Lock Screen, Control Center,
/// AirPods and Mac media keys) and routes its remote commands back to the app.
struct NowPlayingCenter {
    private var infoCenter: MPNowPlayingInfoCenter { .default() }

    /// Wires remote commands. Pause and stop both stop the stream, since a live stream can't resume in place.
    func configureCommands(play: @escaping () -> Void, stop: @escaping () -> Void, toggle: @escaping () -> Void) {
        let commands = MPRemoteCommandCenter.shared()
        commands.playCommand.addTarget { _ in play(); return .success }
        commands.pauseCommand.addTarget { _ in stop(); return .success }
        commands.stopCommand.addTarget { _ in stop(); return .success }
        commands.togglePlayPauseCommand.addTarget { _ in toggle(); return .success }

        // Nothing to skip or scrub on a live radio stream.
        for command in [commands.nextTrackCommand, commands.previousTrackCommand,
                        commands.skipForwardCommand, commands.skipBackwardCommand,
                        commands.changePlaybackPositionCommand] {
            command.isEnabled = false
        }
    }

    func update(isPlaying: Bool, track: Track?, artwork: MPMediaItemArtwork?) {
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: track?.title ?? "DEF CON Radio",
            MPMediaItemPropertyArtist: track?.artist ?? "SomaFM",
            MPMediaItemPropertyAlbumTitle: "DEF CON Radio",
            MPNowPlayingInfoPropertyIsLiveStream: true,
            MPNowPlayingInfoPropertyMediaType: MPNowPlayingInfoMediaType.audio.rawValue,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0,
        ]
        if let artwork {
            info[MPMediaItemPropertyArtwork] = artwork
        }
        infoCenter.nowPlayingInfo = info
        #if os(macOS)
        infoCenter.playbackState = isPlaying ? .playing : .stopped
        #endif
    }

    /// Builds artwork from downloaded image data. Nonisolated because the system calls
    /// the artwork request handler off the main thread.
    nonisolated static func artwork(from data: Data) -> MPMediaItemArtwork? {
        #if canImport(UIKit)
        guard let image = UIImage(data: data) else { return nil }
        #else
        guard let image = NSImage(data: data) else { return nil }
        #endif
        return MPMediaItemArtwork(boundsSize: image.size) { _ in image }
    }
}
