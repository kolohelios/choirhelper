# ChoirHelper - Implementation Plan

## Context

A choir tenor (music reading ~2-2.5/5) needs a practice tool that lets singers photograph their legally-purchased sheet music, hear their part with accompaniment, follow along with a bouncing ball, and get scored on pitch accuracy. This will be an open-source native macOS/iOS SwiftUI app, structured like the AFMBridge project (nix, GitHub Actions, Justfile, conventional commits, jj).

**First piece**: "Living Water" by Emily Crocker (SATB + Piano, Bb major, ~116 BPM, ~2:10)

---

## Architecture Overview

```
Photo(s) of sheet music + "I sing Tenor"
        ↓
OpenRouter Vision Model (Gemini Flash / Claude Sonnet)
        ↓
    MusicXML
        ↓
  Internal Score Model
   ↓         ↓         ↓
Playback   Notation   Lyrics/Karaoke
Engine     (OSMD)     View
   ↓                    ↓
Per-part            Bouncing ball
volume              cursor
   ↓
Microphone → Pitch Detector → Scorer
```

### Key Technology Choices

| Component | Choice | Why |
|-----------|--------|-----|
| Platform | SwiftUI (macOS 15+ / iOS 18+) | Native feel, user preference |
| AI API | OpenRouter (BYOK) | User brings own key. Model flexibility: vision for OCR, text for coaching |
| Audio engine | AVAudioEngine + AVAudioUnitSampler | Per-part volume control, mic input, cursor sync |
| Notation render | WKWebView + OSMD (OpenSheetMusicDisplay) | Only mature MusicXML renderer; MIT licensed |
| MusicXML parsing | Foundation XMLParser (SAX) | Zero dependencies, all Apple platforms |
| Pitch detection | Accelerate vDSP (YIN algorithm) | Low latency, no external deps |
| SoundFont | GeneralUser GS (~30MB, open license) | Good quality choir + piano sounds |
| VCS | Jujutsu (jj) | Per CLAUDE.md |
| Task runner | Just | Per AFMBridge pattern |
| Dev env | Nix flake + direnv | Per AFMBridge pattern |

### iCloud Sync (Simple)

Scores and practice history sync via **iCloud Documents container** (`NSUbiquitousContainerIdentifier`). No custom CloudKit schemas or fancy conflict resolution - just file-based sync:
- Scores saved as `.choirhelper` JSON files in iCloud Documents
- Practice history as append-only session logs
- Works automatically across Mac and iPhone
- Falls back to local storage if iCloud is unavailable

### Why AVAudioEngine (not AVMIDIPlayer)

AVMIDIPlayer is fire-and-forget with no per-channel volume control and no way to know which note is playing. AVAudioEngine lets us create one sampler per part, each with independent volume/mute, and we schedule events ourselves so we always know the current position for the bouncing ball.

```
AVAudioEngine
├── AVAudioUnitSampler (Soprano)  → MixerNode ─┐
├── AVAudioUnitSampler (Alto)     → MixerNode ─┤
├── AVAudioUnitSampler (Tenor)    → MixerNode ─┼→ MainMixer → Output
├── AVAudioUnitSampler (Bass)     → MixerNode ─┤
├── AVAudioUnitSampler (Piano)    → MixerNode ─┘
└── InputNode (Mic) → Tap for pitch detection
```

---

## Project Structure (mirrors AFMBridge)

```
choir_helper/
├── .github/workflows/
│   ├── ci.yml                    # format, lint, test, build
│   ├── pr-stack.yml              # conventional commit validation
│   └── release.yml               # tagged releases
├── Sources/
│   ├── App/                      # SwiftUI entry point
│   │   ├── ChoirHelperApp.swift
│   │   └── ContentView.swift
│   ├── Models/                   # Domain models (zero deps)
│   │   ├── Score.swift
│   │   ├── Part.swift
│   │   ├── Measure.swift
│   │   ├── Note.swift
│   │   ├── Pitch.swift
│   │   ├── Lyric.swift
│   │   ├── TimeSignature.swift
│   │   ├── KeySignature.swift
│   │   └── ChoirHelperError.swift
│   ├── MusicXML/                 # MusicXML parsing
│   │   ├── MusicXMLParser.swift
│   │   └── MusicXMLElements.swift
│   ├── OpenRouter/               # AI API client
│   │   ├── OpenRouterClient.swift
│   │   ├── OpenRouterConfig.swift
│   │   ├── ModelTask.swift
│   │   └── DTOs/
│   │       ├── ChatCompletionRequest.swift
│   │       ├── ChatCompletionResponse.swift
│   │       └── VisionMessage.swift
│   ├── SheetMusicOCR/            # Photo → MusicXML pipeline
│   │   ├── SheetMusicScanner.swift
│   │   └── OCRPrompts.swift
│   ├── Playback/                 # Audio engine
│   │   ├── PlaybackEngine.swift
│   │   ├── MIDIScheduler.swift
│   │   └── SoundFontManager.swift
│   ├── PitchDetection/           # Phase 3
│   │   ├── PitchDetector.swift
│   │   └── NoteComparator.swift
│   ├── Storage/                  # iCloud-synced persistence
│   │   ├── ScoreStorage.swift    # iCloud Documents container
│   │   ├── SettingsStorage.swift
│   │   └── PracticeHistory.swift # Session logs for progress tracking
│   └── Views/                    # SwiftUI views
│       ├── LibraryView.swift
│       ├── PracticeView.swift
│       ├── ScoreView.swift       # OSMD WebView wrapper
│       ├── LyricsView.swift      # Karaoke view
│       ├── PlaybackControls.swift
│       ├── VolumeControls.swift
│       ├── PhotoCaptureView.swift
│       ├── ScanProgressView.swift
│       ├── SettingsView.swift
│       └── Components/
│           ├── BouncingBall.swift
│           └── PitchIndicator.swift
├── Tests/
│   ├── ModelsTests/
│   ├── MusicXMLTests/
│   ├── OpenRouterTests/
│   ├── PlaybackTests/
│   └── SheetMusicOCRTests/
├── Resources/
│   ├── osmd.html                 # OSMD host page
│   ├── osmd.min.js               # Bundled OSMD library
│   ├── GeneralUser.sf2           # SoundFont for playback
│   └── ExamplePieces/
│       └── amazing_grace.musicxml
├── Package.swift
├── AGENTS.md                     # AI agent standards (CLAUDE.md symlinks here)
├── PLAN.md                       # This file
├── README.md
├── LICENSE                       # MIT
├── Justfile                      # format, lint, test, build, validate
├── flake.nix                     # Nix dev environment
├── .envrc                        # use flake
├── .swiftlint.yml
├── .swift-format
├── .markdownlint.json
└── .gitignore
```

---

## User Flow

1. **Import**: User takes photos of their sheet music (camera or photo library)
2. **Configure**: User selects their part(s) ("I sing Tenor" / "I sing Soprano + Descant" / etc.)
3. **Scan**: AI vision model reads the photos → generates MusicXML
4. **Practice**: Dual view (notation + lyrics), bouncing ball, play/pause/tempo controls
5. **Volume**: Sliders for accompaniment and user's part(s) (can mute part to sing alone)
6. **Score** (Phase 3): Microphone listens, compares pitch to expected notes, shows accuracy

### Part Selection (Multi-Select)

Users can select **one or more parts** they sing. Examples:
- A tenor selects just "Tenor"
- A soprano who also sings the descant selects "Soprano" + "Descant"
- Someone covering two parts selects "Tenor 1" + "Tenor 2"

Supported part types:
- Standard SATB (Soprano, Alto, Tenor, Bass)
- Section splits (Soprano 1/2, Alto 1/2, Tenor 1/2, Bass 1/2)
- Special parts (Descant, Optional Descant)
- Any other voicings the AI detects from the score

All selected parts are played louder by default and highlighted in the notation view. Each selected part can still have its own independent volume slider.

---

## Sheet Music OCR Strategy (Two-Pass)

**Pass 1 - Vision extraction** (e.g., `google/gemini-2.0-flash`):
> Analyze this photograph of sheet music. Extract every musical detail: key/time signatures, tempo, notes (pitch + duration), rests, dynamics, lyrics with syllable alignment, ties, slurs. The user says they sing [Tenor]. Identify all parts visible. Output structured text. Mark anything unclear with [UNCLEAR].

**Pass 2 - MusicXML generation** (e.g., `anthropic/claude-sonnet-4`):
> Convert this musical analysis into valid MusicXML 4.0 score-partwise format. Include all parts, lyrics, dynamics. Output only the XML.

Two passes are more reliable than asking a vision model to produce MusicXML directly.

---

## API Key Management

- **BYOK (Bring Your Own Key)**: Users enter their OpenRouter API key in Settings
- Key stored in macOS Keychain / iOS Keychain (not UserDefaults)
- Settings view explains how to get an OpenRouter key with a link
- No app-side API costs; standard BYOK pattern (like Cursor, Continue, etc.)
- Future consideration: AFM fallback for simple tasks that don't need OpenRouter
- App Store distribution is a non-goal for now; GitHub releases + TestFlight

---

## Copyright Approach

- App ships with **zero copyrighted music**
- Users photograph their **own legally-purchased** sheet music
- Photos are sent to OpenRouter for OCR processing (users are informed via privacy notice)
- Generated MusicXML is stored **locally only** on the user's device
- Bundled example: **"Amazing Grace"** - public domain hymn (1779/1835), original SATB arrangement

---

## Incremental Phases

### Phase 1 - Foundation (start here)

**Goal**: Scaffold project, parse MusicXML, play back with per-part volume control.

| # | Commit | What it does |
|---|--------|-------------|
| 1 | `chore(project): scaffold Xcode project and packages` | Package.swift, Justfile, flake.nix, CI, linting configs |
| 2 | `feat(models): define domain model for choral scores` | Score, Part, Measure, Note, Pitch, Lyric types + tests |
| 3 | `feat(openrouter): implement API client` | OpenRouterClient actor, DTOs, vision support + tests |
| 4 | `feat(musicxml): implement MusicXML parser` | SAX parser → Score model, handles SATB + piano + tests |
| 5 | `feat(example): bundle Amazing Grace SATB arrangement` | Hand-crafted public domain MusicXML |
| 6 | `feat(playback): implement MIDI engine with per-part volume` | AVAudioEngine, samplers, MIDIScheduler + tests |
| 7 | `feat(storage): implement iCloud-backed score persistence` | iCloud Documents container + Codable, Keychain for API key |
| 8 | `feat(ui): implement app shell with playback controls` | Library, Practice, Settings views, volume sliders, transport |

### Phase 2 - Visual Experience

| Feature | Implementation |
|---------|---------------|
| Notation rendering | WKWebView + OSMD, JS bridge for cursor control |
| Lyrics/karaoke view | Native SwiftUI, syllable-by-syllable highlighting |
| Bouncing ball | Animated overlay synced to playback engine's currentBeat |
| Tempo control | Slider that adjusts playback BPM |
| Part highlighting | Selected part(s) rendered in accent color in OSMD |
| Photo capture | PHPicker (iOS) / NSOpenPanel (macOS) + camera on iOS |
| OCR pipeline | SheetMusicScanner using two-pass OpenRouter calls |

### Phase 3 - Performance Scoring

| Feature | Implementation |
|---------|---------------|
| Mic input | AVAudioEngine inputNode with tap (buffer 2048 @ 44.1kHz) |
| Pitch detection | YIN algorithm via Accelerate vDSP |
| Scoring | Compare detected freq to expected; ±20 cents = good |
| Visual feedback | Color indicators: green/yellow/red on current note |
| Headphone recommendation | Play-and-record AVAudioSession with echo cancellation |

### Phase 4 - AI Coaching & Progress

| Feature | Implementation |
|---------|---------------|
| Performance analysis | Send score data to OpenRouter text model |
| Practice suggestions | "Focus on measures 15-18, you tend to go flat" |
| Session history | iCloud-synced practice session logs |
| Progress tracking | Charts showing improvement over time per piece |
| Pitch quality heat map | Visual map of the score colored by pitch accuracy - shows at a glance which measures/phrases need work (green=nailed it, yellow=close, red=needs practice) |

---

## Key Domain Types

```swift
struct Score: Codable, Sendable, Identifiable {
    let id: UUID
    var title: String
    var composer: String?
    var keySignature: KeySignature
    var timeSignature: TimeSignature
    var tempo: Int  // BPM
    var parts: [Part]
    var userPartTypes: [PartType]  // ["tenor", "descant"] - multi-select
}

struct Part: Codable, Sendable, Identifiable {
    let id: UUID
    var name: String       // "Tenor", "Piano", "Soprano 1"
    var partType: PartType
    var measures: [Measure]
    var midiChannel: UInt8
    var midiProgram: UInt8 // GM instrument (52=choir aahs, 0=piano)
}

enum PartType: String, Codable, Sendable, CaseIterable {
    case soprano, alto, tenor, bass, piano
    case soprano1, soprano2, alto1, alto2
    case tenor1, tenor2, bass1, bass2
    case descant, accompaniment
}
```

---

## Testing Strategy

- **Protocol-based design**: All services behind protocols with mock implementations
- **80%+ coverage** target (matching AFMBridge)
- **Unit tests**: Models (Codable, Pitch math), MusicXML parser (sample XML), OpenRouter (mock URLProtocol), MIDIScheduler (event generation)
- **Integration tests**: Load example MusicXML → parse → generate MIDI events → verify
- **CI gate**: `just validate` (format + lint + test) must pass before every commit

---

## Verification Plan

1. `just build` compiles clean on macOS
2. `just test` passes all tests with 80%+ coverage
3. `just validate` passes (format + lint + test)
4. App launches, shows Library with bundled Amazing Grace
5. Tap Amazing Grace → PracticeView with playback controls
6. Press play → hear piano + all vocal parts
7. Adjust Tenor volume slider → tenor gets louder/quieter
8. Mute Tenor → hear only accompaniment + other parts
9. (Phase 2) See notation with cursor + lyrics with bouncing ball
10. (Phase 3) Enable mic → see real-time pitch accuracy feedback
