//
//  MainTabView.swift
//  RenalTracker
//

import SwiftUI

struct MainTabView: View {
    @State private var selectedTab: Int = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView(onShowDoctorVisits: { selectedTab = 4 })
                .tabItem {
                    Label("Главная", systemImage: "house")
                }
                .tag(0)
            IndicatorsView()
                .tabItem {
                    Label("Показатели", systemImage: "heart")
                }
                .tag(1)
            LabResultsView()
                .tabItem {
                    Label("Анализы", systemImage: "drop")
                }
                .tag(2)
            MedicationsView()
                .tabItem {
                    Label("Лекарства", systemImage: "pill")
                }
                .tag(3)
            DoctorVisitsView()
                .tabItem {
                    Label("Приёмы", systemImage: "cross.case")
                }
                .tag(4)
        }
    }
}

#Preview {
    MainTabView()
}
