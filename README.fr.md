# Nekko (CatScript)

> [English](./README.md) | [日本語](./README.ja.md)

Une application iOS d'enregistrement, de transcription, de synthèse et de traduction vocale, entièrement propulsée par **Mistral AI**. Un chat en pixel art vous accueille à chaque ouverture de l'application.

## Fonctionnalités

- **Enregistrement** — Capture audio de haute qualité (M4A) via le microphone de l'appareil.
- **Transcription en temps réel** — Sous-titres en direct diffusés pendant l'enregistrement via l'API WebSocket Realtime de Mistral.
- **Transcription par lots avec identification des locuteurs** — Après l'enregistrement, l'audio est transcrit avec des étiquettes de locuteurs (Speaker 1, 2...) grâce à l'API batch Voxtral Mini.
- **Synthèse** — Génère un résumé concis de la transcription avec Mistral Small.
- **Traduction** — Traduit la transcription dans la langue choisie avec Mistral Small.
- **Suivi d'utilisation** — Affiche l'utilisation mensuelle avec une limite de 600 minutes.
- **Widget** — Un widget chat en pixel art pour l'écran d'accueil.

## Utilisation de Mistral AI

| Fonctionnalité | Modèle | API |
|----------------|--------|-----|
| Transcription en temps réel | `voxtral-mini-transcribe-realtime-2602` | WebSocket `wss://api.mistral.ai/v1/audio/transcriptions/realtime` |
| Transcription par lots (identification des locuteurs) | `voxtral-mini-latest` | `POST /v1/audio/transcriptions` avec `diarize=true` |
| Synthèse | `mistral-small-latest` | `POST /v1/chat/completions` |
| Traduction | `mistral-small-latest` | `POST /v1/chat/completions` |

Tous les appels API sont effectués **directement depuis l'application iOS** vers `api.mistral.ai`. Aucun serveur backend n'est nécessaire.

## Architecture

```
iOS App (Nekko)
    ├── Pendant l'enregistrement : WebSocket → Mistral Realtime (voxtral-mini-transcribe-realtime-2602)
    ├── Après l'enregistrement : POST /v1/audio/transcriptions (voxtral-mini-latest, diarize=true)
    ├── Synthèse et traduction : POST /v1/chat/completions (mistral-small-latest)
    └── Données : SwiftData (local) / UserDefaults (clé API)
```

- **Transcription en temps réel** : L'audio est converti en PCM mono 16 kHz (S16LE) et envoyé par fragments de 480 ms via WebSocket.
- **Transcription par lots, synthèse et traduction** : Appels HTTPS standard directement vers l'API REST de Mistral.
- **Persistance** : Les enregistrements et transcriptions sont stockés localement avec SwiftData.

## Stack technique

| Technologie | Utilisation |
|-------------|-------------|
| SwiftUI | Interface utilisateur |
| SwiftData | Persistance des données |
| AVAudioEngine | Enregistrement audio |
| URLSessionWebSocketTask | Transcription en temps réel Mistral |
| Mistral Voxtral Mini Realtime | Transcription en direct pendant l'enregistrement |
| Mistral Voxtral Mini | Transcription par lots avec identification des locuteurs |
| Mistral Small | Synthèse et traduction |
| WidgetKit | Widget pour l'écran d'accueil |

## Installation

### 1. Application iOS

1. Ouvrir `Nekko.xcodeproj` dans Xcode.
2. Configurer votre équipe dans Signing & Capabilities.
3. Exécuter sur un iPhone (appareil ou simulateur).

### 2. Clé API Mistral

1. Obtenir une clé API sur [Mistral AI](https://mistral.ai).
2. Dans l'application, aller dans l'onglet **Réglages** → **Mistral AI** → saisir votre **clé API Mistral**.

La clé est stockée localement sur l'appareil (UserDefaults) et est utilisée pour toutes les fonctionnalités : transcription en temps réel, transcription par lots, synthèse et traduction.

### 3. Widget (optionnel)

1. Dans Xcode, aller dans File → New → Target → Widget Extension.
2. Nommer `NekkoWidget`.
3. Remplacer les fichiers générés par ceux du répertoire `NekkoWidget/`.

### 4. Backend (optionnel)

Le dépôt inclut `NekkoBackend` (Vapor), mais **l'application n'en a pas besoin**. Il peut être utilisé comme proxy optionnel ou pour la journalisation.

```bash
cd NekkoBackend
export MISTRAL_API_KEY=your_key_here
swift run
```

## Langues prises en charge

Japonais, English, Français, العربية, Deutsch, Español, हिन्दी, Italiano, 한국어, Nederlands, Português, Русский, 中文

## Licence

Hackathon Project — Mistral AI Worldwide Hackathon 2026
