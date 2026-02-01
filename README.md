# CaptionThis

Real-time speech transcription and translation for macOS. CaptionThis captures audio from your microphone or any running application and provides live captions with optional translation — all processed on-device for privacy.

## Features

- **Real-time transcription** — Speech is transcribed as you speak using Apple's on-device speech recognition, with automatic punctuation
- **Live translation** — Translates speech in real time as words are recognized, using Apple's on-device Translation framework
- **Delayed translation** — Translates only after a sentence is finalized, producing more accurate results
- **Multiple audio sources** — Capture audio from the microphone or from a specific application (e.g., Safari, Zoom, Discord)
- **Four-panel display** — Separate panels for finalized transcript, in-progress transcript, finalized translation, and in-progress translation
- **Supported languages** — English, French, Japanese, and Portuguese (Brazilian)
- **Two-hop translation** — When a direct language pair is unavailable, translates through English as an intermediate step
- **Pin on top** — Keep the window floating above other windows
- **Fully on-device** — All speech recognition and translation happens locally, no data is sent to external servers

## Requirements

- macOS 26 or later
- Xcode 26 or later (to build from source)

## Permissions

CaptionThis requires the following permissions on first launch:

- **Microphone** — To capture audio for transcription
- **Speech Recognition** — To transcribe audio using Apple's Speech framework
- **Screen Recording** (optional) — Required only when capturing audio from a specific application

## Building

1. Clone the repository
2. Open `CaptionThis.xcodeproj` in Xcode
3. Build and run (Cmd+R)

No external dependencies are required.

## Usage

1. Select an **input language** (the language being spoken)
2. Optionally select a **caption language** to enable translation, or set to "None" to disable
3. Choose an **audio source** — microphone or a running application
4. If translation is enabled, choose **Live** mode (translates as you speak) or **Delayed** mode (translates after each pause)
5. Press **Start** (or press Space) to begin transcription
6. Finalized sentences appear in the "Final" panels; text currently being spoken appears in the "In Progress" panels
7. Use the trash icon on each panel to clear its contents independently

## License

This project is licensed under the GNU General Public License v3.0. See [LICENSE](https://www.gnu.org/licenses/gpl-3.0.en.html) for details.
