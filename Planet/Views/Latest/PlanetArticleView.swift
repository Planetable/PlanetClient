//
//  PlanetArticleView.swift
//  Planet
//
//  Created by Kai on 2/20/23.
//

import SwiftUI


struct PlanetArticleView: View {
    var article: PlanetArticle
    
    @State private var articleURL: String?
    
    var body: some View {
        Group {
            if let articleURL, let url = URL(string: articleURL) {
                PlanetArticleWebView(url: url)
                    .navigationBarTitleDisplayMode(.inline)
                    .navigationTitle(article.title)
            } else {
                VStack {
                    Text("Failed to load article.")
                        .foregroundColor(.secondary)
                    Button {
                        Task {
                            await self.reloadAction()
                        }
                    } label: {
                        Text("Reload")
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .task {
            await self.reloadAction()
        }
    }
    
    private func reloadAction() async {
        await MainActor.run {
            self.articleURL = nil
        }
        guard await PlanetSettingsViewModel.shared.serverIsOnline() else { return }
        guard let planetID = article.planetID else { return }
        let serverURL = PlanetSettingsViewModel.shared.serverURL
        let url = URL(string: serverURL)!.appendingPathComponent("/v0/planets/my/\(planetID.uuidString)/public/\(article.id)/index.html")
        await MainActor.run {
            self.articleURL = url.absoluteString
        }
    }
}

struct PlanetArticleView_Previews: PreviewProvider {
    static var previews: some View {
        PlanetArticleView(article: .empty())
    }
}
