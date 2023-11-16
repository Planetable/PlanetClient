//
//  PlanetLatestView.swift
//  Planet
//
//  Created by Kai on 2/20/23.
//

import SwiftUI


struct PlanetLatestView: View {
    @EnvironmentObject private var appViewModel: PlanetAppViewModel
    @EnvironmentObject private var latestViewModel: PlanetLatestViewModel
    @EnvironmentObject private var myPlanetsViewModel: PlanetMyPlanetsViewModel

    @State private var isCreating: Bool = false
    @State private var isFailedRefreshing: Bool = false
    @State private var errorMessage: String = ""

    var body: some View {
        /* First, load what is already on disk, then attempt to pull the latest content from the remote source.
        */
        NavigationStack(path: $appViewModel.latestTabPath) {
            Group {
                if latestViewModel.myArticles.count == 0 {
                    VStack {
                        // TODO: Redesign the way to present empty state.
                        Text("No articles.")
                            .foregroundColor(.secondary)
                        Button {
                            refreshAction(skipAlert: false)
                        } label: {
                            Text("Reload")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else {
                    List {
                        ForEach(latestViewModel.myArticles, id: \.id) { article in
                            if let planetID = article.planetID, let planet = Planet.getPlanet(forID: planetID.uuidString) {
                                NavigationLink(destination: PlanetArticleView(planet: planet, article: article)) {
                                    PlanetLatestItemView(planet: planet, article: article)
                                }
                                .listRowSeparator(.hidden)
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .disabled(isCreating)
            .navigationTitle(PlanetAppTab.latest.name())
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button {
                        isCreating.toggle()
                    } label: {
                        Image(systemName: "plus")
                            .resizable()
                    }
                    .sheet(isPresented: $isCreating) {
                        PlanetNewArticleView()
                            .environmentObject(myPlanetsViewModel)
                    }
                }
            }
            .refreshable {
                refreshAction(skipAlert: false)
            }
            .task {
                refreshAction()
            }
            .onReceive(NotificationCenter.default.publisher(for: .reloadArticles)) { _ in
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
                let articles = try await PlanetManager.shared.getMyArticles()
                await MainActor.run {
                    withAnimation {
                        self.latestViewModel.updateMyArticles(articles)
                    }
                }
            } catch {
                await MainActor.run {
                    withAnimation {
                        self.latestViewModel.updateMyArticles([])
                    }
                    guard skipAlert == false else { return }
                    self.isFailedRefreshing = true
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
}

struct PlanetLatestView_Previews: PreviewProvider {
    static var previews: some View {
        PlanetLatestView()
    }
}
