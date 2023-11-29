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
    @EnvironmentObject private var latestViewModel: PlanetLatestViewModel

    @State private var isCreating: Bool = false
    @State private var isFailedRefreshing: Bool = false
    @State private var errorMessage: String = ""
    
    var body: some View {
        Group {
            if myPlanetsViewModel.myPlanets.count == 0 {
                Spacer()
                Text("No planets.")
                    .foregroundColor(.secondary)
                Button {
                    isCreating.toggle()
                } label: {
                    Text("Create")
                }
                .buttonStyle(.borderedProminent)
                Button {
                    refreshAction(skipAlert: false)
                } label: {
                    Text("Reload")
                }
                .buttonStyle(.bordered)
                Spacer()
            } else {
                List {
                    ForEach(myPlanetsViewModel.myPlanets, id: \.id) { planet in
                        NavigationLink {
                            PlanetMyPlanetInfoView(planet: planet)
                                .environmentObject(latestViewModel)
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
        .task {
            refreshAction()
        }
        .onReceive(NotificationCenter.default.publisher(for: .updatePlanets)) { _ in
            refreshAction()
        }
        .alert(isPresented: $isFailedRefreshing) {
            Alert(title: Text("Failed to Reload"), message: Text(errorMessage), dismissButton: .cancel(Text("Dismiss")))
        }
    }
    
    private func refreshAction(skipAlert: Bool = true) {
        Task(priority: .utility) {
            do {
                let planets = try await PlanetManager.shared.getMyPlanets()
                await MainActor.run {
                    withAnimation {
                        self.myPlanetsViewModel.updateMyPlanets(planets)
                    }
                }
            } catch PlanetError.APIServerIsInactiveError {
                let planets = try PlanetManager.shared.getMyOfflinePlanetsFromAllNodes()
                await MainActor.run {
                    withAnimation {
                        self.myPlanetsViewModel.updateMyPlanets(planets)
                    }
                }
            } catch {
                await MainActor.run {
                    withAnimation {
                        self.myPlanetsViewModel.updateMyPlanets([])
                    }
                }
                guard skipAlert == false else { return }
                self.isFailedRefreshing = true
                self.errorMessage = error.localizedDescription
            }
        }
    }
}

struct PlanetMyPlanetsView_Previews: PreviewProvider {
    static var previews: some View {
        PlanetMyPlanetsView()
    }
}
