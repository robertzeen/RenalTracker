//
//  HomeQuoteView.swift
//  RenalTracker
//

import SwiftUI

struct HomeQuoteView: View {
    let quote: DailyQuote

    var body: some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(Color.blue.opacity(0.6))
                .frame(width: 3)
                .cornerRadius(2)

            VStack(alignment: .leading, spacing: 6) {
                Text(quote.text)
                    .font(.system(size: 14))
                    .italic()
                    .foregroundStyle(.primary)
                    .lineSpacing(3)
                if let author = quote.author {
                    Text("— \(author)")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(14)
        }
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(.separator), lineWidth: 0.5))
        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
    }
}
