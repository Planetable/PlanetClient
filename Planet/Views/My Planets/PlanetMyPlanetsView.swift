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
    @State private var isFailedRefreshing: Bool = false
    @State private var errorMessage: String = ""

    var body: some View {
        NavigationStack(path: $appViewModel.planetsTabPath) {
            Group {
                if myPlanetsViewModel.myPlanets.count == 0 {
                    VStack {
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
                    }
                } else {
                    List {
                        ForEach(myPlanetsViewModel.myPlanets, id: \.id) { planet in
                            NavigationLink(destination: PlanetMyPlanetInfoView(planet: planet)) {
                                planet.listItemView()
                            }
                        }
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
