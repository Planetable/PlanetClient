//
//  PlanetAppView.swift
//  Planet
//
//  Created by Kai on 2/16/23.
//

import SwiftUI


struct PlanetAppView: View {
    @EnvironmentObject private var appViewModel: PlanetAppViewModel
    @EnvironmentObject private var latestViewModel: PlanetLatestViewModel
    @EnvironmentObject private var myPlanetsViewModel: PlanetMyPlanetsViewModel
    @EnvironmentObject private var settingsViewModel: PlanetSettingsViewModel
    
    var body: some View {
        TabView(selection: $appViewModel.selectedTab) {
            PlanetLatestView()
                .environmentObject(appViewModel)
                .environmentObject(latestViewModel)
                .environmentObject(myPlanetsViewModel)
                .tabItem {
                    Label(PlanetAppTab.latest.name(), systemImage: "newspaper")
                }
                .tag(PlanetAppTab.latest)
            PlanetMyPlanetsView()
                .environmentObject(appViewModel)
                .environmentObject(myPlanetsViewModel)
                .tabItem {
                    Label(PlanetAppTab.myPlanets.name(), systemImage: "globe")
                }
                .tag(PlanetAppTab.myPlanets)
            PlanetSettingsView()
                .environmentObject(appViewModel)
                .environmentObject(settingsViewModel)
                .tabItem {
                    Label(PlanetAppTab.settings.name(), systemImage: "gear")
                }
                .tag(PlanetAppTab.settings)
        }
    }
}

struct PlanetAppView_Previews: PreviewProvider {
    static var previews: some View {
        PlanetAppView()
    }
}
