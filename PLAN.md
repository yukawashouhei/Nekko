# Nekko 実装プラン（現行）

本ドキュメントは、現在の Nekko アプリの実装方針・アーキテクチャ・機能一覧をまとめたものです。

---

## 1. 概要

- **アプリ名**: Nekko (CatScript)
- **種別**: Mistral AI を利用した録音・文字起こし・要約・翻訳の iOS アプリ
- **対応端末**: iPhone（実機・シミュレータ両対応）
- **バックエンド**: アプリ本体は **Mistral API に直接接続**。NekkoBackend はオプション（同一リポジトリ内に存在するが、アプリの必須要件ではない）

---

## 2. アーキテクチャ

```
┌─────────────────────────────────────────────────────────────┐
│  iOS App (Nekko)                                              │
│  ┌─────────────┐  ┌──────────────────┐  ┌─────────────────┐│
│  │ 録音タブ     │  │ 記録タブ          │  │ 設定タブ         ││
│  │ ・録音       │  │ ・文字起こし表示  │  │ ・APIキー        ││
│  │ ・リアルタイム│  │ ・要約            │  │ ・使用量(600分/月)││
│  │   文字起こし │  │ ・翻訳            │  │ ・About          ││
│  └──────┬──────┘  └────────┬─────────┘  └────────┬──────────┘│
│         │                   │                     │           │
│  ┌──────▼───────────────────▼─────────────────────▼──────────┐│
│  │  Services                                                 ││
│  │  MistralRealtimeService (WebSocket)  ← 録音中のライブ文字起こし ││
│  │  BackendAPIService (HTTPS)           ← 文字起こし・要約・翻訳   ││
│  │  AudioRecorderService, UsageTracker, NetworkMonitor        ││
│  └──────┬───────────────────┬────────────────────────────────┘│
│         │                   │                                  │
│  ┌──────▼──────┐      ┌─────▼─────┐                            │
│  │ SwiftData   │      │ UserDefaults                           ││
│  │ (Recording) │      │ (API Key)  │                            │
│  └────────────┘      └───────────┘                            │
└─────────────────────────────────────────────────────────────┘
         │                   │
         │    HTTPS / WSS     │
         ▼                   ▼
┌─────────────────────────────────────────────────────────────┐
│  Mistral AI API (https://api.mistral.ai)                     │
│ ・Realtime: wss://.../audio/transcriptions/realtime          │
│ ・Transcribe: POST /v1/audio/transcriptions (diarize=true)   │
│ ・Chat: POST /v1/chat/completions (要約・翻訳)                 │
└─────────────────────────────────────────────────────────────┘
```

- **認証**: 設定タブで入力した Mistral API キーを `UserDefaults` に保存し、全 API 呼び出しで `Authorization: Bearer <key>` として使用。
- **バックエンド非依存**: 文字起こし・要約・翻訳はすべて iOS アプリから Mistral API に直接リクエストするため、実機でも同一ネットワークの Mac サーバーは不要。

---

## 3. 機能一覧

| 機能 | 説明 | 使用 API / 技術 |
|------|------|------------------|
| 録音 | マイクから M4A で録音 | AVAudioEngine, AVAudioFile |
| リアルタイム文字起こし | 録音中に画面上にテキストをストリーミング表示 | Mistral Realtime (WebSocket), voxtral-mini-transcribe-realtime-2602 |
| バッチ文字起こし | 録音停止後に高精度で文字起こし＋話者識別 | POST /v1/audio/transcriptions, voxtral-mini-latest, diarize=true |
| 要約 | 文字起こしテキストの要約生成 | POST /v1/chat/completions, mistral-small-latest |
| 翻訳 | 記録タブで翻訳先言語を選んで翻訳 | POST /v1/chat/completions, mistral-small-latest |
| 使用量管理 | 月 600 分までの利用制限表示 | UsageTracker, ローカル集計 |
| ウィジェット | ホーム画面にドット絵の猫 | WidgetKit |

---

## 4. 主要コンポーネント

### 4.1 サービス層

- **MistralRealtimeService**:  
  - `wss://api.mistral.ai/v1/audio/transcriptions/realtime?model=voxtral-mini-transcribe-realtime-2602` に WebSocket 接続。  
  - メッセージ: `session.update`（audio_format: pcm_s16le, 16kHz）, `input_audio.append`, `input_audio.flush`, `input_audio.end`。  
  - 受信: `session.created`, `transcription.text.delta`, `transcription.done`, `error`。  
  - 録音バッファは 16kHz モノ S16LE に変換して 480ms 単位で送信。

- **BackendAPIService**:  
  - Mistral API 直接呼び出し（バックエンドサーバーは使用しない）。  
  - `transcribeWithSegments`: 音声ファイルを multipart で送信、`text` と `segments`（話者・開始・終了・テキスト）を返す。  
  - `summarize` / `translate`: Chat Completions で要約・翻訳。

- **AudioRecorderService**: 録音開始/停止、バッファを `MistralRealtimeService.processAudioBuffer` に渡す。

- **UsageTracker**: 録音秒数を加算し、月間 600 分制限を管理。

### 4.2 データモデル

- **Recording** (SwiftData):  
  - id, title, createdAt, duration, language, audioFileName, liveTranscription, finalTranscription, summary, isProcessing, segments（JSON）, translation, translationLanguage。  
  - `decodedSegments` で話者付きセグメントを取得。  
- **TranscriptionSegmentData**: speaker, start, end, text。`speakerLabel` で "speaker_0" → "Speaker 1" 形式に変換。

### 4.3 UI

- **録音タブ**: 言語選択、録音ボタン、波形、リアルタイム文字起こしエリア（接続中／認識中／テキスト表示）。
- **記録タブ**: 一覧 → 詳細。詳細で「記録」「要約」「翻訳」セグメント、話者付き文字起こし、翻訳実行。
- **設定タブ**: 今月の使用量（600 分）、Mistral API キー、About（モデル名・Powered by Mistral AI）。

---

## 5. 対応言語

日本語, English, Français, العربية, Deutsch, Español, हिन्दी, Italiano, 한국어, Nederlands, Português, Русский, 中文

---

## 6. 今後の拡張候補（未実装）

- プレミアムプラン（利用制限解除）の仮実装の具体化
- 録音タブでのリアルタイム翻訳表示
- NotebookLM など外部アプリへの送信
- NekkoBackend をオプションのプロキシとして利用する構成（現状はアプリから直接 API 呼び出し）

---

*最終更新: 現行実装（Mistral 直接接続・リアルタイム WebSocket・話者識別・翻訳対応）に基づく*
