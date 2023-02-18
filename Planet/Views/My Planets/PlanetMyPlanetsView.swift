//
//  PlanetMyPlanetsView.swift
//  Planet
//
//  Created by Kai on 2/19/23.
//

import SwiftUI


struct PlanetMyPlanetsView: View {
    @EnvironmentObject private var appViewModel: PlanetAppViewModel
    @EnvironmentObject private var myPlanetsViewModel: PlanetMyPlanetsViewModel

    var body: some View {
        NavigationStack(path: $appViewModel.planetsTabPath) {
            List {
                ForEach(myPlanetsViewModel.myPlanets, id: \.id) { planet in
                    Text(planet.name)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .navigationTitle(PlanetAppTab.myPlanets.name())
            .refreshable {
                Task(priority: .utility) {
                    do {
                        try await refreshAction()
                    } catch {
                        debugPrint("failed to refresh: \(error)")
                    }
                }
            }
        }
    }
        
    private func refreshAction() async throws {
        let planets = try await PlanetManager.shared.getMyPlanets()
        await MainActor.run {
            self.myPlanetsViewModel.updateMyPlanets(planets)
        }
    }
}

struct PlanetMyPlanetsView_Previews: PreviewProvider {
    static var previews: some View {
        PlanetMyPlanetsView()
    }
}
