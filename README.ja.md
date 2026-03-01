# Nekko (CatScript)

> [English](./README.md) | [Français](./README.fr.md)

**Mistral AI** を活用した、録音・文字起こし・要約・翻訳の iOS アプリ。アプリを開くたびにピクセルアートの猫が出迎えます。

## 主な機能

- **録音** — マイクから高品質で録音（M4A 形式）。
- **リアルタイム文字起こし** — 録音中、Mistral の Realtime WebSocket API で話した内容をその場でライブ表示。
- **バッチ文字起こし（話者識別）** — 録音停止後、Voxtral Mini のバッチ API で話者ごとにセグメント分け（Speaker 1, 2...）して文字起こし。
- **要約** — Mistral Small で文字起こしテキストの要約を生成。
- **翻訳** — Mistral Small で選択した言語に翻訳。
- **使用量管理** — 1 ヶ月あたり 600 分の利用制限と現在の使用量を表示。
- **ウィジェット** — ホーム画面にドット絵の猫ウィジェット。

## Mistral AI の利用箇所

| 機能 | モデル | API |
|------|--------|-----|
| リアルタイム文字起こし | `voxtral-mini-transcribe-realtime-2602` | WebSocket `wss://api.mistral.ai/v1/audio/transcriptions/realtime` |
| バッチ文字起こし（話者識別） | `voxtral-mini-latest` | `POST /v1/audio/transcriptions`（`diarize=true`） |
| 要約 | `mistral-small-latest` | `POST /v1/chat/completions` |
| 翻訳 | `mistral-small-latest` | `POST /v1/chat/completions` |

すべての API 呼び出しは iOS アプリから `api.mistral.ai` に**直接接続**します。バックエンドサーバーは不要です。

## アーキテクチャ

```
iOS App (Nekko)
    ├── 録音中: WebSocket → Mistral Realtime (voxtral-mini-transcribe-realtime-2602)
    ├── 録音後: POST /v1/audio/transcriptions (voxtral-mini-latest, diarize=true)
    ├── 要約・翻訳: POST /v1/chat/completions (mistral-small-latest)
    └── データ: SwiftData（ローカル）/ UserDefaults（API キー）
```

- **リアルタイム文字起こし**: 音声を 16kHz モノ PCM（S16LE）に変換し、480ms 単位で WebSocket 送信。
- **バッチ文字起こし・要約・翻訳**: Mistral REST API に HTTPS で直接リクエスト。
- **データ保存**: SwiftData で録音・文字起こしをローカルに保存。

## 使用技術

| 技術 | 用途 |
|------|------|
| SwiftUI | ユーザーインターフェース |
| SwiftData | データ永続化 |
| AVAudioEngine | 音声録音 |
| URLSessionWebSocketTask | Mistral リアルタイム文字起こし |
| Mistral Voxtral Mini Realtime | 録音中のライブ文字起こし |
| Mistral Voxtral Mini | バッチ文字起こし（話者識別） |
| Mistral Small | 要約・翻訳 |
| WidgetKit | ホーム画面ウィジェット |

## セットアップ

### 1. iOS アプリ

1. `Nekko.xcodeproj` を Xcode で開く。
2. Signing & Capabilities でチームを設定。
3. iPhone 実機またはシミュレータで実行。

### 2. Mistral API キー

1. [Mistral AI](https://mistral.ai) で API キーを取得。
2. アプリ内の **設定** タブ → **Mistral AI** → **Mistral API キー** に入力。

API キーは端末内（UserDefaults）にのみ保存され、リアルタイム文字起こし・バッチ文字起こし・要約・翻訳のすべてに使用されます。

### 3. ウィジェット（任意）

1. Xcode で File → New → Target → Widget Extension を選択。
2. Name を `NekkoWidget` にして作成。
3. 生成されたファイルを `NekkoWidget/` の既存ファイルで置き換え。

### 4. バックエンド（任意）

リポジトリには `NekkoBackend`（Vapor）が含まれていますが、**アプリの動作には不要**です。プロキシやログ用途でのみ利用できます。

```bash
cd NekkoBackend
export MISTRAL_API_KEY=your_key_here
swift run
```

## 対応言語

日本語, English, Français, العربية, Deutsch, Español, हिन्दी, Italiano, 한국어, Nederlands, Português, Русский, 中文

## ライセンス

Hackathon Project — Mistral AI Worldwide Hackathon 2026
