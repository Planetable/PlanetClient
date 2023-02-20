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

    @State private var isCreating: Bool = false

    var body: some View {
        NavigationStack(path: $appViewModel.latestTabPath) {
            Group {
                if latestViewModel.myArticles.count == 0 {
                    VStack {
                        Text("No articles.")
                            .foregroundColor(.secondary)
                        Button {
                            Task(priority: .utility) {
                                do {
                                    try await refreshAction()
                                } catch {
                                    debugPrint("failed to refresh: \(error)")
                                }
                            }
                        } label: {
                            Text("Reload")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else {
                    List {
                        ForEach(latestViewModel.myArticles, id: \.id) { article in
                            NavigationLink(destination: PlanetArticleView(article: article)) {
                                PlanetLatestItemView(article: article)
                            }
                            .listRowSeparator(.hidden)
                        }
                    }
                    .listStyle(.plain)
                }
            }
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
                    }
                }
            }
            .refreshable {
                Task(priority: .utility) {
                    do {
                        try await refreshAction()
                    } catch {
                        debugPrint("failed to refresh: \(error)")
                    }
                }
            }
            .task(priority: .utility) {
                do {
                    try await refreshAction()
                } catch {
                    debugPrint("failed to refresh: \(error)")
                }
            }
        }
    }
    
    private func refreshAction() async throws {
        let articles = try await PlanetManager.shared.getMyArticles()
        await MainActor.run {
            withAnimation {
                self.latestViewModel.updateMyArticles(articles)
            }
        }
    }
}

struct PlanetLatestView_Previews: PreviewProvider {
    static var previews: some View {
        PlanetLatestView()
    }
}
