//
//  SupportedLanguage.swift
//  Nekko
//
//  Created by 湯川昇平 on 2026/02/28.
//

import Foundation

enum SupportedLanguage: String, CaseIterable, Identifiable, Codable {
    case japanese = "ja"
    case english = "en"
    case french = "fr"
    case arabic = "ar"
    case german = "de"
    case spanish = "es"
    case hindi = "hi"
    case italian = "it"
    case korean = "ko"
    case dutch = "nl"
    case portuguese = "pt"
    case russian = "ru"
    case chinese = "zh"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .japanese: "日本語"
        case .english: "English"
        case .french: "Français"
        case .arabic: "العربية"
        case .german: "Deutsch"
        case .spanish: "Español"
        case .hindi: "हिन्दी"
        case .italian: "Italiano"
        case .korean: "한국어"
        case .dutch: "Nederlands"
        case .portuguese: "Português"
        case .russian: "Русский"
        case .chinese: "中文"
        }
    }

    var locale: Locale {
        Locale(identifier: rawValue)
    }

    var sfSpeechLocale: Locale {
        switch self {
        case .japanese: Locale(identifier: "ja-JP")
        case .english: Locale(identifier: "en-US")
        case .french: Locale(identifier: "fr-FR")
        case .arabic: Locale(identifier: "ar-SA")
        case .german: Locale(identifier: "de-DE")
        case .spanish: Locale(identifier: "es-ES")
        case .hindi: Locale(identifier: "hi-IN")
        case .italian: Locale(identifier: "it-IT")
        case .korean: Locale(identifier: "ko-KR")
        case .dutch: Locale(identifier: "nl-NL")
        case .portuguese: Locale(identifier: "pt-BR")
        case .russian: Locale(identifier: "ru-RU")
        case .chinese: Locale(identifier: "zh-CN")
        }
    }

    var mistralLanguageCode: String { rawValue }
}
