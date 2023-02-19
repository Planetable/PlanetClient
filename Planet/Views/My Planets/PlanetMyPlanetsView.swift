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
    
    @State private var isCreating: Bool = false

    var body: some View {
        NavigationStack(path: $appViewModel.planetsTabPath) {
            List {
                ForEach(myPlanetsViewModel.myPlanets, id: \.id) { planet in
                    NavigationLink(destination: PlanetMyPlanetInfoView(planet: planet)) {
                        PlanetMyPlanetsItemView(planet: planet)
                    }
                }
            }
            .navigationTitle(PlanetAppTab.myPlanets.name())
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button {
                        isCreating.toggle()
                    } label: {
                        Image(systemName: "plus")
                            .resizable()
                    }
                    .sheet(isPresented: $isCreating) {
                        PlanetNewPlanetView()
                    }
                }
            }
            .refreshable {
                Task(priority: .utility) {
                    do {
                        try await refreshAction()
                    } catch {
                        debugPrint("failed to refresh: \(error)")
                    }
                }
            }
            .task(priority: .utility) {
                do {
                    try await refreshAction()
                } catch {
                    debugPrint("failed to refresh: \(error)")
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .updatePlanets)) { _ in
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
            withAnimation {
                self.myPlanetsViewModel.updateMyPlanets(planets)
            }
        }
        NotificationCenter.default.post(name: .reloadPlanets, object: nil)
    }
}

struct PlanetMyPlanetsView_Previews: PreviewProvider {
    static var previews: some View {
        PlanetMyPlanetsView()
    }
}
