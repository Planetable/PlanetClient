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
    @State private var serverStatus: Bool = false

    init(planet: Planet, article: PlanetArticle) {
        _isWaitingEdit = State(wrappedValue: UserDefaults.standard.value(forKey: .editingArticleKey(byID: article.id)) != nil)
        self.planet = planet
        self.article = article
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
        .navigationTitle(article.title ?? "")
        .ignoresSafeArea(edges: .bottom)
        .task {
            await reloadAction()
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
        .fullScreenCover(isPresented: $isEdit) {
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
                        debugPrint("failed to delete article: \(error)")
                    }
                }
            } label: {
                Text("Delete Article")
            }
        } message: {
            Text("Are you sure you want to delete \(article.title ?? "untitled")? This action cannot to undone.")
        }
        .onReceive(NotificationCenter.default.publisher(for: .reloadArticle(byID: article.id))) { _ in
            Task { @MainActor in
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
        .task(priority: .background) {
            Task { @MainActor in
                self.isWaitingEdit = UserDefaults.standard.value(forKey: .editingArticleKey(byID: article.id)) != nil
            }
        }
    }

    private func reloadAction() async {
        await MainActor.run {
            self.articleURL = nil
        }
        self.serverStatus = await PlanetStatus.shared.serverIsOnline()
        if !self.serverStatus {
            if let planetArticleURL = PlanetManager.shared.getPlanetArticleURL(forID: planet.id, articleID: article.id) {
                debugPrint("got article: \(planetArticleURL)")
                await MainActor.run {
                    self.articleURL = planetArticleURL
                }
            }
        } else {
            if let url = URL(string: PlanetAppViewModel.shared.currentServerURLString)?.appending(path: "/\(planet.id)/\(article.id)/index.html"), let nowURL = url.withTimestamp() {
                debugPrint("loading article: \(nowURL)")
                await MainActor.run {
                    self.articleURL = nowURL
                }
            }
        }
    }

    @ViewBuilder
    private func optionsMenu() -> some View {
        VStack {
            if !serverStatus {
                Text("Offline Mode")
                    .foregroundStyle(.secondary)
                Divider()
            }

            Button {
                Task { @MainActor in
                    await self.reloadAction()
                }
                Task.detached(priority: .background) {
                    if await PlanetStatus.shared.serverIsOnline() {
                        do {
                            try await PlanetArticleDownloader.shared
                                .download(
                                    byArticleID: self.article.id,
                                    andPlanetID: self.planet.id,
                                    forceDownloadAttachments: true
                                )
                        } catch {
                            debugPrint("failed to download article \(self.article.id): \(error)")
                        }
                    }
                }
            } label: {
                Label("Reload", systemImage: "arrow.clockwise")
            }

            Divider()

            Button {
                Task {
                    if await PlanetStatus.shared.serverIsOnline() {
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
            .disabled(!serverStatus)

            if let shareLink = article.shareLink {
                ShareLink("Share", item: shareLink)
            }

            Divider()

            Button(role: .destructive) {
                isDelete.toggle()
            } label: {
                Label("Delete", systemImage: "trash")
            }
            .disabled(!serverStatus)
        }
    }
}
