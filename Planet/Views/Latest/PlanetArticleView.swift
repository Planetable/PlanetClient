//
//  PlanetArticleView.swift
//  Planet
//
//  Created by Kai on 2/20/23.
//

import SwiftUI


struct PlanetArticleView: View {
    @Environment(\.dismiss) private var dismiss
    
    var planet: Planet
    var article: PlanetArticle

    @State private var articleURL: String?
    @State private var isEdit: Bool = false
    @State private var isShare: Bool = false
    @State private var isDelete: Bool = false
    
    var body: some View {
        Group {
            if let articleURL, let url = URL(string: articleURL) {
                PlanetArticleWebView(url: url)
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
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(article.title)
        .ignoresSafeArea(edges: .vertical)
        .task {
            await self.reloadAction()
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    optionsMenu()
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $isEdit) {
            PlanetEditArticleView(planet: planet, article: article)
        }
        .confirmationDialog("Delete Planet", isPresented: $isDelete) {
            Button(role: .cancel) {
            } label: {
                Text("Cancel")
            }
            Button(role: .destructive) {
                Task(priority: .userInitiated) {
                    do {
                        try await PlanetManager.shared.deleteArticle(id: article.id, planetID: planet.id)
                        self.dismiss()
                    } catch {
                        debugPrint("failed to delete article: \(article.title), error: \(error)")
                    }
                }
            } label: {
                Text("Delete Article")
            }
        } message: {
            Text("Are you sure you want to delete \(article.title)? This action cannot to undone.")
        }
        .onReceive(NotificationCenter.default.publisher(for: .reloadArticle(byID: article.id))) { _ in
            Task {
                await self.reloadAction()
            }
        }
    }
    
    private func reloadAction() async {
        // MARK: TODO: use local content
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
    
    @ViewBuilder
    private func optionsMenu() -> some View {
        VStack {
            Button {
                isEdit.toggle()
            } label: {
                Label("Edit", systemImage: "pencil.circle")
            }
            Button {
                
            } label: {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            Divider()
            Button(role: .destructive) {
                isDelete.toggle()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}
