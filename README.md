# Nekko (CatScript)

Mistral AI を活用した録音・文字起こし・要約・翻訳の iOS アプリ。ウィジェットではドット絵の猫が様々なアクティビティをしています。

## 主な機能

- **録音**: マイクから高品質で録音（M4A）
- **リアルタイム文字起こし**: 録音中に Mistral のリアルタイム API でライブ表示
- **文字起こし（話者識別）**: 録音停止後に Voxtral Mini で文字起こしし、話者ごとに表示（Speaker 1, 2...）
- **要約**: 文字起こしテキストを Mistral Small で要約
- **翻訳**: 記録詳細で翻訳先言語を選んで翻訳
- **使用量**: 1 ヶ月あたり 600 分までの利用制限を表示
- **ウィジェット**: ホーム画面にドット絵の猫ウィジェット

## アーキテクチャ

アプリは **Mistral API に直接接続**します。バックエンドサーバーは不要で、実機・シミュレータのどちらでも同じように動作します。

```
iOS App (Nekko)
    ├── 録音中: WebSocket → Mistral Realtime (voxtral-mini-transcribe-realtime-2602)
    ├── 文字起こし: POST /v1/audio/transcriptions (voxtral-mini-latest, diarize=true)
    ├── 要約・翻訳: POST /v1/chat/completions (mistral-small-latest)
    └── データ: SwiftData (ローカル) / UserDefaults (API キー)
```

- **リアルタイム文字起こし**: Mistral Realtime WebSocket（16kHz モノ PCM）
- **バッチ文字起こし・要約・翻訳**: Mistral REST API をアプリから直接呼び出し
- **データ保存**: SwiftData（Recording モデル）

詳細な構成は [PLAN.md](./PLAN.md) を参照してください。

## セットアップ

### 1. iOS アプリ

1. `Nekko.xcodeproj` を Xcode で開く
2. Signing & Capabilities でチームを設定
3. iPhone 実機またはシミュレータで実行

### 2. Mistral API キー

1. [Mistral AI](https://mistral.ai) で API キーを取得
2. アプリ内の **設定** タブ → **Mistral AI** → **Mistral API キー** に入力

API キーは端末内（UserDefaults）にのみ保存され、文字起こし・要約・翻訳・リアルタイム文字起こしのすべてに使用されます。

### 3. ウィジェット（任意）

1. Xcode で File > New > Target > Widget Extension を選択
2. Name: `NekkoWidget` で作成
3. 生成されたファイルを `NekkoWidget/` の既存ファイルで置き換え

### 4. バックエンド（任意）

リポジトリには `NekkoBackend`（Vapor）が含まれていますが、**アプリの動作には不要**です。  
サーバー側でプロキシやログを取りたい場合のみ利用できます。

```bash
cd NekkoBackend
export MISTRAL_API_KEY=your_key_here
swift run
```

サーバーは `http://localhost:8080` で起動します（アプリは現在この URL を参照しません）。

## 使用技術

| 技術 | 用途 |
|------|------|
| SwiftUI | UI |
| SwiftData | データ永続化 |
| AVAudioEngine | 音声録音 |
| URLSessionWebSocketTask | Mistral リアルタイム文字起こし |
| Mistral Voxtral Mini Realtime | 録音中のライブ文字起こし |
| Mistral Voxtral Mini | バッチ文字起こし（話者識別） |
| Mistral Small | 要約・翻訳 |
| WidgetKit | ホーム画面ウィジェット |

## 対応言語

日本語, English, Français, العربية, Deutsch, Español, हिन्दी, Italiano, 한국어, Nederlands, Português, Русский, 中文

## ライセンス

Hackathon Project - Mistral AI Worldwide Hackathon 2026
