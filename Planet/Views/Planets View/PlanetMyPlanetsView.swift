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
    @State private var isFailedRefreshing: Bool = false
    @State private var errorMessage: String = ""
    
    var body: some View {
        Group {
            if appViewModel.myPlanets.count == 0 {
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
        debugPrint("refresh action in my planets view, skip alert: \(skipAlert)")
        Task {
            do {
                try await self.appViewModel.reloadMyPlanets()
            } catch {
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
