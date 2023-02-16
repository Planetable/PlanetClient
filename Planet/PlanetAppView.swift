//
//  PlanetAppView.swift
//  Planet
//
//  Created by Kai on 2/16/23.
//

import SwiftUI


struct PlanetAppView: View {
    @EnvironmentObject private var appViewModel: PlanetAppViewModel
    
    var body: some View {
        TabView(selection: $appViewModel.selectedTab) {
            Text(PlanetAppTab.latest.name())
                .tabItem {
                    Label(PlanetAppTab.latest.name(), systemImage: "newspaper")
                }
                .tag(PlanetAppTab.latest)
            Text(PlanetAppTab.myPlanets.name())
                .tabItem {
                    Label(PlanetAppTab.myPlanets.name(), systemImage: "globe")
                }
                .tag(PlanetAppTab.myPlanets)
            Text(PlanetAppTab.settings.name())
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
