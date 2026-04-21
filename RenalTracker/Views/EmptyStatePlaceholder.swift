//
//  EmptyStatePlaceholder.swift
//  RenalTracker
//

import SwiftUI

/// Единый компонент пустого состояния: круглая иконка с эмодзи, заголовок,
/// описание и tinted-кнопка действия.
///
/// Использование:
///     EmptyStatePlaceholder(
///         emoji: "🏥",
///         title: "Нет записей о приёмах",
///         description: "Здесь будет история ваших\nприёмов у врача",
///         buttonTitle: "Добавить первый приём",
///         action: { isShowingAddVisit = true }
///     )
struct EmptyStatePlaceholder: View {
    let emoji: String
    let title: String
    let description: String
    let buttonTitle: String
    let action: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 80, height: 80)
                Text(emoji)
                    .font(.system(size: 36))
            }
            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)
            Text(description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button(action: action) {
                Text(buttonTitle)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.blue)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 80)
    }
}

#Preview {
    EmptyStatePlaceholder(
        emoji: "🏥",
        title: "Нет записей о приёмах",
        description: "Здесь будет история ваших\nприёмов у врача",
        buttonTitle: "Добавить первый приём",
        action: { }
    )
}
