//
//  PlanetDraftsView.swift
//  Planet
//

import SwiftUI

struct PlanetDraftsView: View {
    @EnvironmentObject private var appViewModel: PlanetAppViewModel

    var body: some View {
        Group {
            if appViewModel.drafts.count == 0 {
                Spacer()
                Text("No drafts.")
                    .foregroundColor(.secondary)
                Spacer()
            } else {
                List {
                    ForEach(appViewModel.drafts, id: \.id) { article in
                        Group {
                            if let planetID = article.planetID, let planet = Planet.getPlanet(forID: planetID.uuidString) {
                                PlanetLatestItemView(planet: planet, article: article)
                            } else {
                                PlanetLatestItemView(planet: nil, article: article)
                            }
                        }
                        .listRowSeparator(.hidden)
                        .onTapGesture {
                            Task { @MainActor in
                                self.appViewModel.resumedArticleDraft = article
                                self.appViewModel.resumeNewArticle = true
                            }
                        }
                    }
                    .onDelete { indexSet in
                        Task { @MainActor in
                            indexSet.forEach { i in
                                let draft = self.appViewModel.drafts[i]
                                self.appViewModel.removeDraft(draft)
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
    }
}

#Preview {
    PlanetDraftsView()
}
