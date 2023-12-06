//
//  PlanetMyPlanetsView.swift
//  Planet
//
//  Created by Kai on 2/19/23.
//

import SwiftUI


struct PlanetMyPlanetsView: View {
    @EnvironmentObject private var appViewModel: PlanetAppViewModel

    @State private var isCreating: Bool = false
    
    var body: some View {
        Group {
            if appViewModel.myPlanets.count == 0 {
                Spacer()
                Text("No planets.")
                    .foregroundColor(.secondary)
                Button {
                    refreshAction(skipAlert: false)
                } label: {
                    Text("Reload")
                }
                .buttonStyle(.bordered)
                Spacer()
            } else {
                List {
                    ForEach(appViewModel.myPlanets, id: \.id) { planet in
                        NavigationLink {
                            PlanetMyPlanetInfoView(planet: planet)
                                .environmentObject(appViewModel)
                        } label: {
                            planet.listItemView()
                        }
                        .listRowSeparator(.hidden)
                    }
                }
                .listStyle(.plain)
            }
        }
        .refreshable {
            refreshAction(skipAlert: false)
        }
        .onReceive(NotificationCenter.default.publisher(for: .updatePlanets)) { _ in
            refreshAction()
        }
    }
    
    private func refreshAction(skipAlert: Bool = true) {
        Task {
            do {
                try await self.appViewModel.reloadPlanets()
            } catch {
                guard skipAlert == false else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    Task { @MainActor in
                        self.appViewModel.failedToReload = true
                        self.appViewModel.failedMessage = error.localizedDescription
                    }
                }
            }
        }
    }
}

struct PlanetMyPlanetsView_Previews: PreviewProvider {
    static var previews: some View {
        PlanetMyPlanetsView()
    }
}
