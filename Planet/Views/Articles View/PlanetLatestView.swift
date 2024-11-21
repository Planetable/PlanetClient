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

    var body: some View {
        /* First, load what is already on disk, then attempt to pull the latest content from the remote source.
         */
        Group {
            if appViewModel.myArticles.count == 0 {
                Spacer()
                Text("No articles.")
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
                    ForEach(appViewModel.filteredResults, id: \.id) { article in
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
            refreshAction(skipAlert: false)
        }
        .searchable(text: $appViewModel.searchText, prompt: "Search articles")
        .onReceive(NotificationCenter.default.publisher(for: .reloadArticles)) { _ in
            refreshAction()
        }
    }

    private func refreshAction(skipAlert: Bool = true) {
        Task {
            do {
                try await self.appViewModel.reloadArticles()
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

struct PlanetLatestView_Previews: PreviewProvider {
    static var previews: some View {
        PlanetLatestView()
    }
}
