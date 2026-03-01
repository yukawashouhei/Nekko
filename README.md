# Nekko (CatScript)

> [日本語](./README.ja.md) | [Français](./README.fr.md)

An iOS app for recording, transcribing, summarizing, and translating speech — powered entirely by **Mistral AI**. A pixel-art cat greets you each time you open the app.

## Features

- **Recording** — High-quality audio capture (M4A) via the device microphone.
- **Realtime transcription** — Live captions streamed during recording through Mistral's Realtime WebSocket API.
- **Batch transcription with speaker diarization** — After recording, the audio is transcribed with speaker labels (Speaker 1, 2...) using the Voxtral Mini batch API.
- **Summarization** — Generates a concise summary of the transcript using Mistral Small.
- **Translation** — Translates the transcript into a chosen language using Mistral Small.
- **Usage tracking** — Displays monthly usage against a 600-minute limit.
- **Widget** — A pixel-art cat widget for the home screen.

## How Mistral AI is Used

| Feature | Model | API |
|---------|-------|-----|
| Realtime transcription | `voxtral-mini-transcribe-realtime-2602` | WebSocket `wss://api.mistral.ai/v1/audio/transcriptions/realtime` |
| Batch transcription (diarization) | `voxtral-mini-latest` | `POST /v1/audio/transcriptions` with `diarize=true` |
| Summarization | `mistral-small-latest` | `POST /v1/chat/completions` |
| Translation | `mistral-small-latest` | `POST /v1/chat/completions` |

All API calls are made **directly from the iOS app** to `api.mistral.ai`. No backend server is required.

## Architecture

```
iOS App (Nekko)
    ├── While recording : WebSocket → Mistral Realtime (voxtral-mini-transcribe-realtime-2602)
    ├── After recording : POST /v1/audio/transcriptions (voxtral-mini-latest, diarize=true)
    ├── Summary & Translation : POST /v1/chat/completions (mistral-small-latest)
    └── Data : SwiftData (local) / UserDefaults (API key)
```

- **Realtime transcription**: Audio is converted to 16 kHz mono PCM (S16LE) and streamed in 480 ms chunks over WebSocket.
- **Batch transcription, summarization & translation**: Standard HTTPS calls directly to the Mistral REST API.
- **Persistence**: Recordings and transcripts are stored locally using SwiftData.

## Tech Stack

| Technology | Purpose |
|------------|---------|
| SwiftUI | User interface |
| SwiftData | Local data persistence |
| AVAudioEngine | Audio recording |
| URLSessionWebSocketTask | Mistral Realtime transcription |
| Mistral Voxtral Mini Realtime | Live transcription during recording |
| Mistral Voxtral Mini | Batch transcription with speaker diarization |
| Mistral Small | Summarization and translation |
| WidgetKit | Home screen widget |

## Setup

### 1. iOS App

1. Open `Nekko.xcodeproj` in Xcode.
2. Configure your team under Signing & Capabilities.
3. Run on an iPhone (device or simulator).

### 2. Mistral API Key

1. Obtain an API key from [Mistral AI](https://mistral.ai).
2. In the app, go to the **Settings** tab → **Mistral AI** → enter your **Mistral API Key**.

The key is stored locally on the device (UserDefaults) and is used for all features: realtime transcription, batch transcription, summarization, and translation.

### 3. Widget (optional)

1. In Xcode, go to File → New → Target → Widget Extension.
2. Name it `NekkoWidget`.
3. Replace the generated files with the ones in the `NekkoWidget/` directory.

### 4. Backend (optional)

The repository includes `NekkoBackend` (Vapor), but **the app does not require it**. It can be used as an optional proxy or for logging.

```bash
cd NekkoBackend
export MISTRAL_API_KEY=your_key_here
swift run
```

## Supported Languages

Japanese, English, Français, العربية, Deutsch, Español, हिन्दी, Italiano, 한국어, Nederlands, Português, Русский, 中文

## License

Hackathon Project — Mistral AI Worldwide Hackathon 2026
