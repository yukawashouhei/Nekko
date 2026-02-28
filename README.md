# Nekko (CatScript)

Mistral AIを活用した録音・文字起こし・要約iOSアプリ。ウィジェットではドット絵の猫が様々なアクティビティをしています。

## アーキテクチャ

```
iOS App (Nekko)  →  Backend (Vapor)  →  Mistral AI API
    ↓ (ローカル)
SFSpeechRecognizer (リアルタイム文字起こし)
```

- **リアルタイム文字起こし**: SFSpeechRecognizer (iOS純正、オフライン対応)
- **高品質文字起こし**: Mistral Voxtral Mini (バックエンド経由)
- **要約**: Mistral Small 3.1 (バックエンド経由)
- **データ保存**: SwiftData (ローカル)

## セットアップ

### iOS App

1. `Nekko.xcodeproj` をXcodeで開く
2. Signing & Capabilities でチームを設定
3. iPhoneまたはシミュレータで実行

### Backend

```bash
cd NekkoBackend
export MISTRAL_API_KEY=your_key_here
swift run
```

サーバーが `http://localhost:8080` で起動します。

### Widget

1. Xcode で File > New > Target > Widget Extension を選択
2. Name: `NekkoWidget` で作成
3. 生成されたファイルを `NekkoWidget/` ディレクトリのファイルで置き換え

## 使用技術

| 技術 | 用途 |
|------|------|
| SwiftUI | UI |
| SwiftData | データ永続化 |
| AVAudioEngine | 音声録音 |
| SFSpeechRecognizer | リアルタイム文字起こし |
| Vapor | バックエンドサーバー |
| Mistral Voxtral Mini | 高品質文字起こし |
| Mistral Small 3.1 | テキスト要約 |
| WidgetKit | ホーム画面ウィジェット |

## 対応言語

日本語, English, Français, العربية, Deutsch, Español, हिन्दी, Italiano, 한국어, Nederlands, Português, Русский, 中文

## ライセンス

Hackathon Project - Mistral AI Worldwide Hackathon 2026
