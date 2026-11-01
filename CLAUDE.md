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
- `flow.fm/RadioPlayer.swift` — `@Observable` model wrapping `AVPlayer`; plays the stream, polls now-playing,
  handles audio session interruptions (iOS 27 `didBecomeInactive` / `resumptionRecommendation` notifications).
- `flow.fm/NowPlayingCenter.swift` — Lock Screen / Control Center / media keys via `MPNowPlayingInfoCenter`
  and `MPRemoteCommandCenter`. Artwork handler is `nonisolated` because the system calls it off-main.
- `flow.fm/MyApp.swift` — owns the single `RadioPlayer` (so remote commands register once) and injects it
  via `.environment`.
- `flow.fm/ContentView.swift` — player UI (logo, title, current track, play/stop).
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
  - `https://somafm.com/songs/defcon.json` — recent tracks (title, artist, album, unix `date`); first entry is on air.

## Known gotchas
- **AVPlayer does not surface ICY `StreamTitle`** for these streams (tested AAC and MP3 via
  `AVPlayerItemMetadataOutput` and `timedMetadata`), even though the server sends it in the
  first metadata block and then only on song change. Now playing therefore polls
  `songs/defcon.json` every 30 s while playing.
- One mirror once accepted the connection but sent no headers for >5 s; another responded
  immediately. Plan for mirror fallback and generous timeouts.
- Live stream: on play, create a fresh `AVPlayerItem` so playback starts at the live edge.

## SomaFM etiquette
SomaFM is commercial-free and listener-supported. Keep API polling light (≥30 s) and plan
to link to their donate page (https://somafm.com/support/).

## Roadmap
Done:
- Minimal player (play/stop, logo, now playing).
- Background audio, Lock Screen / Control Center / media keys, interruption handling.

Next candidates:
1. Resolve `.pls` and fail over between mirrors.
2. Quality picker (AAC 128/64/32, MP3 256/128).
3. Song history list from `songs/defcon.json`.
