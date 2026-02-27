# ChoirHelper

A practice tool for choir singers. Photograph your sheet music, hear your part with accompaniment,
follow along with a bouncing ball, and get scored on pitch accuracy.

## Features

- **Sheet Music OCR**: Take photos of your legally-purchased sheet music and have AI extract the notation
- **Per-Part Playback**: Hear each voice part (SATB) and piano independently with volume control
- **Bouncing Ball**: Follow along with synchronized lyrics and notation highlighting
- **Pitch Scoring**: Get real-time feedback on your pitch accuracy (Phase 3)
- **AI Coaching**: Receive practice suggestions based on your performance (Phase 4)

## Requirements

- macOS 15+ or iOS 18+
- Xcode 16+
- [OpenRouter](https://openrouter.ai/) API key (BYOK - bring your own key)

## Development Setup

```bash
# Enter Nix development environment
nix develop
# Or with direnv
direnv allow

# Install Homebrew tools (if not already installed)
brew install swift-format swiftlint

# Run all quality checks
just validate

# Build
just build

# Run tests
just test
```

## Architecture

ChoirHelper is a native SwiftUI app structured as a Swift Package with modular targets:

| Target | Purpose |
|--------|---------|
| Models | Domain types (Score, Part, Note, Pitch, etc.) |
| MusicXML | SAX parser for MusicXML files |
| OpenRouter | AI API client (BYOK via OpenRouter) |
| SheetMusicOCR | Photo → MusicXML pipeline |
| Playback | AVAudioEngine-based MIDI playback |
| Storage | iCloud Documents persistence + Keychain |

## How It Works

1. **Import**: Photograph your sheet music (camera or photo library)
2. **Configure**: Select your part ("I sing Tenor", "I sing Soprano", etc.)
3. **Scan**: AI vision model reads the photos → generates MusicXML
4. **Practice**: Play back with per-part volume control, notation display, and lyrics

## Copyright

- Ships with **zero copyrighted music**
- Users photograph their **own legally-purchased** sheet music
- Bundled example: "Amazing Grace" (public domain, 1779/1835)

## License

MIT - see [LICENSE](LICENSE)
