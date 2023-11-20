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

    @State private var articleURL: URL?
    @State private var isEdit: Bool = false
    @State private var isWaitingEdit: Bool = false
    @State private var isOfflineEdit: Bool = false
    @State private var isShare: Bool = false
    @State private var isDelete: Bool = false
    
    init(planet: Planet, article: PlanetArticle) {
        _isWaitingEdit = State(wrappedValue: UserDefaults.standard.value(forKey: .editingArticleKey(byID: article.id)) != nil)
        self.planet = planet
        self.article = article
        let serverURL = PlanetSettingsViewModel.shared.serverURL
        let url = URL(string: serverURL)!.appendingPathComponent("/v0/planets/my/\(planet.id)/public/\(article.id)/index.html")
        self.articleURL = url
    }
    
    var body: some View {
        Group {
            if let articleURL {
                PlanetArticleWebView(url: articleURL)
            } else {
                VStack {
                    ProgressView()
                        .controlSize(.regular)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(article.title)
        .ignoresSafeArea(edges: .vertical)
        .task {
            debugPrint("on task reload action")
            await self.reloadAction()
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if isWaitingEdit {
                    ProgressView()
                        .progressViewStyle(.circular)
                } else {
                    Menu {
                        optionsMenu()
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
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
            debugPrint("reloading article: \(article.id)")
            Task {
                await self.reloadAction()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .startEditingArticle(byID: article.id))) { _ in
            Task { @MainActor in
                self.isWaitingEdit = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .endEditingArticle(byID: article.id))) { _ in
            Task { @MainActor in
                self.isWaitingEdit = false
            }
        }
        .alert(isPresented: $isWaitingEdit) {
            Alert(title: Text("Updating Post"), message: Text("Please wait for a few seconds"), dismissButton: .cancel(Text("Dismiss")))
        }
        .alert(isPresented: $isOfflineEdit) {
            // MARK: TODO: offline eidt?
            Alert(title: Text("Offline Edit"), message: Text("Server is not online, all edit will be saved locally until connected."), dismissButton: .cancel(Text("OK")))
        }
    }
    
    private func reloadAction() async {
        await MainActor.run {
            self.articleURL = nil
        }
        if await PlanetSettingsViewModel.shared.serverIsOnline() {
            let serverURL = PlanetSettingsViewModel.shared.serverURL
            let url = URL(string: serverURL)!.appendingPathComponent("/v0/planets/my/\(planet.id)/public/\(article.id)/index.html")
            await MainActor.run {
                self.articleURL = url
            }
        } else {
            let offlineArticleURL = try? await PlanetManager.shared.getOfflineArticle(id: article.id, planetID: planet.id)
            await MainActor.run {
                self.articleURL = offlineArticleURL
            }
        }
    }
    
    @ViewBuilder
    private func optionsMenu() -> some View {
        VStack {
            Button {
                Task {
                    if await PlanetSettingsViewModel.shared.serverIsOnline() {
                        await MainActor.run {
                            self.isEdit.toggle()
                        }
                    } else {
                        await MainActor.run {
                            self.isOfflineEdit.toggle()
                        }
                    }
                }
            } label: {
                Label("Edit", systemImage: "pencil.circle")
            }

            if let articleURL {
                ShareLink("Share", item: articleURL)
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
