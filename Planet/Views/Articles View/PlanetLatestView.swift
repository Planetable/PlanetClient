//
//  PlanetLatestView.swift
//  Planet
//
//  Created by Kai on 2/20/23.
//

import SwiftUI


struct PlanetLatestView: View {
    @EnvironmentObject private var appViewModel: PlanetAppViewModel

    @State private var isCreating: Bool = false
    @State private var isFailedRefreshing: Bool = false
    @State private var errorMessage: String = ""
    
    var body: some View {
        /* First, load what is already on disk, then attempt to pull the latest content from the remote source.
         */
        Group {
            if appViewModel.myArticles.count == 0 {
                Spacer()
                Text("No articles.")
                    .foregroundColor(.secondary)
                Button {
                    refreshAction()
                } label: {
                    Text("Reload")
                }
                .buttonStyle(.borderedProminent)
                Spacer()
            } else {
                List {
                    ForEach(appViewModel.myArticles, id: \.id) { article in
                        if let planetID = article.planetID, let planet = Planet.getPlanet(forID: planetID.uuidString) {
                            let destination = PlanetArticleView(planet: planet, article: article)
                            NavigationLink(destination: destination) {
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
        .refreshable {
            refreshAction()
        }
        .onReceive(NotificationCenter.default.publisher(for: .reloadArticles)) { _ in
            refreshAction()
        }
        .alert(isPresented: $isFailedRefreshing) {
            Alert(title: Text("Failed to Reload"), message: Text(errorMessage), dismissButton: .cancel(Text("Dismiss")))
        }
    }
    
    private func refreshAction(skipAlert: Bool = true) {
        Task {
            do {
                try await self.appViewModel.reloadMyArticles()
            } catch {
                guard skipAlert == false else { return }
                self.isFailedRefreshing = true
                self.errorMessage = error.localizedDescription
            }
        }
    }
}

struct PlanetLatestView_Previews: PreviewProvider {
    static var previews: some View {
        PlanetLatestView()
    }
}
