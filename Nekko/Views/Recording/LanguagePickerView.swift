//
//  LanguagePickerView.swift
//  Nekko
//
//  Created by 湯川昇平 on 2026/02/28.
//

import SwiftUI

struct LanguagePickerView: View {
    @Binding var selectedLanguage: SupportedLanguage

    var body: some View {
        Menu {
            ForEach(SupportedLanguage.allCases) { language in
                Button {
                    selectedLanguage = language
                } label: {
                    HStack {
                        Text(language.displayName)
                        if language == selectedLanguage {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "globe")
                    .font(.subheadline)
                Text(selectedLanguage.displayName)
                    .font(.subheadline.weight(.medium))
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial, in: Capsule())
        }
        .tint(.primary)
    }
}

#Preview {
    LanguagePickerView(selectedLanguage: .constant(.japanese))
}
