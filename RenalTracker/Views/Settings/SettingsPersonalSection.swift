//
//  SettingsPersonalSection.swift
//  RenalTracker
//

import SwiftUI

struct SettingsPersonalSection: View {
    @Binding var firstName: String
    @Binding var lastName: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ЛИЧНЫЕ ДАННЫЕ")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(.leading, 4)

            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("ИМЯ")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                        TextField("Имя", text: $firstName)
                            .font(.system(size: 15, weight: .medium))
                    }
                    Spacer()
                }
                .padding(14)

                Divider().padding(.leading, 14)

                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("ФАМИЛИЯ")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                        TextField("Фамилия", text: $lastName)
                            .font(.system(size: 15, weight: .medium))
                    }
                    Spacer()
                }
                .padding(14)
            }
            .background(Color(.secondarySystemBackground))
            .cornerRadius(16)
            .overlay(RoundedRectangle(cornerRadius: 16)
                .stroke(Color(.separator), lineWidth: 0.5))
        }
    }
}
