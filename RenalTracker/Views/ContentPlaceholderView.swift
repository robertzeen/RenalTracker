//
//  ContentPlaceholderView.swift
//  RenalTracker
//

import SwiftUI

struct ContentPlaceholderView: View {
    let title: String

    var body: some View {
        VStack {
            Spacer()
            Text(title)
                .font(.title)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    ContentPlaceholderView(title: "Показатели")
}
