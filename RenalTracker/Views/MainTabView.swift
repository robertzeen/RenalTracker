//
//  MainTabView.swift
//  RenalTracker
//

import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("Главная", systemImage: "house")
                }
            IndicatorsView()
                .tabItem {
                    Label("Показатели", systemImage: "heart")
                }
            LabResultsView()
                .tabItem {
                    Label("Анализы", systemImage: "drop")
                }
            MedicationsView()
                .tabItem {
                    Label("Лекарства", systemImage: "pill")
                }
            ProfileView()
                .tabItem {
                    Label("Профиль", systemImage: "person")
                }
        }
    }
}

#Preview {
    MainTabView()
}
