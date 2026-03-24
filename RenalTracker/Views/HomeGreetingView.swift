//
//  HomeGreetingView.swift
//  RenalTracker
//

import SwiftUI

struct HomeGreetingView: View {
    let greeting: String
    let displayName: String
    let statusText: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(greeting), \(displayName)!")
                .font(.title2)
                .fontWeight(.bold)
            if let status = statusText {
                Text(status)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
