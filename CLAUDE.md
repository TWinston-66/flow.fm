# flow.fm

A SwiftUI client for SomaFM's **DEF CON Radio** (https://somafm.com/defcon/).
Single multiplatform target `flow.fm`: iPhone, iPad and Mac (deployment target 27.2).

## Working style
- Build slowly, one small feature at a time. Don't add features beyond what's asked.
- Verify each step: build for macOS (Xcode `BuildProject`) **and** iOS Simulator
  (`xcodebuild -scheme flow.fm -destination 'generic/platform=iOS Simulator' build CODE_SIGNING_ALLOWED=NO`).
- iOS Simulator device interaction isn't available on this machine; use `RunCodeSnippet`
  against `RadioPlayer.swift` to exercise playback logic.

## Code layout
- `flow.fm/RadioPlayer.swift` — `@Observable` model wrapping `AVPlayer`; resolves mirrors from the selected
  quality's `.pls` (falls back to ice2/ice5/ice6), fails over with a 10 s connect timeout and on mid-stream
  drops, polls now-playing, owns the app-only `volume` (`AVPlayer.volume`, persisted in UserDefaults), and
  handles audio session interruptions (iOS 27 `didBecomeInactive` / `resumptionRecommendation` notifications).
  `init(mirrors:)` lets you inject URLs (e.g. an unroutable `https://10.255.255.1/...` to simulate a hang).
  Persists `quality` (changing it while playing reconnects). `recentTracks` holds the song feed;
  `track` is its first entry. `refreshTracks()` is also called from the view's `.task`.
- `flow.fm/StreamQuality.swift` — the five stream formats with their `.pls` and fallback mirror URLs.
  Raw values are persisted in UserDefaults; don't rename cases.
- `flow.fm/NowPlayingCenter.swift` — Lock Screen / Control Center / media keys via `MPNowPlayingInfoCenter`
  and `MPRemoteCommandCenter`. Artwork handler is `nonisolated` because the system calls it off-main.
- `flow.fm/MyApp.swift` — owns the single `RadioPlayer` (so remote commands register once) and injects it
  via `.environment`. macOS uses a single `Window` (id `MyApp.mainWindowID`, default 420×760, min 360×480)
  plus a `.window`-style `MenuBarExtra` (icon switches between `radio` and `dot.radiowaves.left.and.right`
  while playing); iOS uses a `WindowGroup`. On macOS, closing the window switches the activation policy to
  `.accessory` (no Dock icon, stays in the menu bar); reopening switches back to `.regular`.
- `flow.fm/ContentView.swift` — player UI in a `ScrollView`: logo, current track, play/stop, volume,
  quality menu, Support SomaFM link, and "Recently Played" (`RecentTracksView`, feed minus the on-air song).
- `flow.fm/MenuBarPlayerView.swift` — macOS-only compact panel: logo, track, play/stop, volume, quality,
  donate link, Open flow.fm, Quit.
- `flow.fm/PlayerControls.swift` — shared `VolumeSlider`, `QualityPicker`, `SupportSomaFMLink`.
- Default actor isolation is `MainActor`; Swift 5 mode with approachable concurrency.
- macOS App Sandbox is on; `ENABLE_OUTGOING_NETWORK_CONNECTIONS = YES` is required for streaming.
- `UIBackgroundModes = [audio]` keeps the stream playing in the background on iPhone/iPad.

## How the DEF CON stream works
- Icecast 2.4 HTTP stream (not HLS): one long-lived GET returning continuous audio.
- Playlists list mirrors (`ice2`, `ice5`, `ice6.somafm.com`):
  | Format | Bitrate | Playlist | Stream path |
  |---|---|---|---|
  | AAC | 128k | `defcon130.pls` | `/defcon-128-aac` |
  | AAC+ | 64k | `defcon64.pls` | `/defcon-64-aac` |
  | AAC+ | 32k | `defcon32.pls` | `/defcon-32-aac` |
  | MP3 | 256k | `defcon256.pls` | `/defcon-256-mp3` |
  | MP3 | 128k | `defcon.pls` | `/defcon-128-mp3` |
- AAC stream is `Content-Type: audio/aac` (ADTS), `icy-metaint: 45000`.
- JSON APIs:
  - `https://api.somafm.com/channels.json` — channel info, logos (120/256/512), playlists, listeners, `lastPlaying`.
  - `https://somafm.com/songs/defcon.json` — last 15 tracks (title, artist, album, `date` as a *string* of
    unix seconds, `albumArt` usually empty); first entry is on air.

## Known gotchas
- **AVPlayer does not surface ICY `StreamTitle`** for these streams (tested AAC and MP3 via
  `AVPlayerItemMetadataOutput` and `timedMetadata`), even though the server sends it in the
  first metadata block and then only on song change. Now playing therefore polls
  `songs/defcon.json` every 30 s while playing.
- One mirror once accepted the connection but sent no headers for >5 s; another responded
  immediately. Hence mirror failover.
- **A hung `AVPlayerItem` blocks the same `AVPlayer` from loading the next item** (verified: next
  mirror never became ready even after 30 s). Call `item.asset.cancelLoading()` before moving on.
- Live stream: on play, create a fresh `AVPlayerItem` so playback starts at the live edge.

## SomaFM etiquette
SomaFM is commercial-free and listener-supported. Keep API polling light (≥30 s). Both the main
window and the menu bar panel link to their donate page (https://somafm.com/support/).

## Roadmap
Done:
- Minimal player (play/stop, logo, now playing).
- Background audio, Lock Screen / Control Center / media keys, interruption handling.
- Mirror failover via `.pls`; app-only volume slider.
- Quality picker (AAC 128/64/32, MP3 256/128) and Recently Played list.
- Support SomaFM link; macOS menu bar player.
- macOS portrait default window size; Dock icon hides when the window is closed.

Next candidates: none planned yet — ask the user.
