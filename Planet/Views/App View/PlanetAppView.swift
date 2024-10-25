import SwiftUI

struct PlanetAppView: View {
    @EnvironmentObject private var appViewModel: PlanetAppViewModel
    @EnvironmentObject private var settingsViewModel: PlanetSettingsViewModel

    @State private var isServerInactive: Bool = false
    @State private var serverStatus: Bool = true {
        didSet {
            guard serverStatus else { return }
            if appViewModel.selectedTab == .myPlanets {
                Task.detached(priority: .utility) {
                    try? await self.appViewModel.reloadPlanets()
                }
            } else if appViewModel.selectedTab == .latest {
                Task.detached(priority: .utility) {
                    try? await self.appViewModel.reloadArticles()
                }
            }
        }
    }

    var body: some View {
        NavigationStack(path: $appViewModel.path) {
            VStack {
                switch appViewModel.selectedTab {
                case .latest:
                    PlanetLatestView()
                        .environmentObject(appViewModel)
                case .drafts:
                    PlanetDraftsView()
                        .environmentObject(appViewModel)
                default:
                    PlanetMyPlanetsView()
                        .environmentObject(appViewModel)
                }
            }
            .onChange(of: appViewModel.selectedTab) { _ in
                self.checkServerStatus()
            }
            .onReceive(NotificationCenter.default.publisher(for: .updateServerStatus)) { _ in
                self.checkServerStatus()
            }
            .navigationTitle(navigationTitle())
            .navigationBarTitleDisplayMode(.inline)
            .alert(isPresented: $appViewModel.chooseServer) {
                if appViewModel.currentNodeID == nil {
                    Alert(
                        title: Text("Welcome to Planet"),
                        message: Text("Please choose a server to get started."),
                        primaryButton: .default(Text("Choose")) {
                            appViewModel.showSettings.toggle()
                        },
                        secondaryButton: .cancel(Text("Later"))
                    )
                } else {
                    Alert(
                        title: Text("Check Server Status"),
                        message: Text("Failed to reload from last connected server, please check server status then try again."),
                        primaryButton: .default(Text("Check")) {
                            appViewModel.showSettings.toggle()
                        },
                        secondaryButton: .cancel(Text("Later"))
                    )
                }
            }
            .toolbar {
                ToolbarItemGroup(placement: .topBarLeading) {
                    Button {
                        appViewModel.showSettings.toggle()
                    } label: {
                        Image(systemName: "gear")
                    }
                    
                    if !self.serverStatus {
                        if appViewModel.selectedTab != .drafts {
                            Button {
                                isServerInactive = true
                            } label: {
                                Image(systemName: "bolt.slash")
                            }
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    switch appViewModel.selectedTab {
                    case .latest:
                        Button {
                            Task {
                                if await PlanetStatus.shared.serverIsOnline() {
                                    await MainActor.run {
                                        self.appViewModel.newArticle.toggle()
                                    }
                                } else {
                                    await MainActor.run {
                                        self.isServerInactive = true
                                    }
                                }
                            }
                        } label: {
                            Image(systemName: "plus")
                        }
                        .help("New Article")
                    case .myPlanets:
                        Button {
                            Task {
                                if await PlanetStatus.shared.serverIsOnline() {
                                    await MainActor.run {
                                        self.appViewModel.newPlanet.toggle()
                                    }
                                } else {
                                    await MainActor.run {
                                        self.isServerInactive = true
                                    }
                                }
                            }
                        } label: {
                            Image(systemName: "plus")
                        }
                        .help("New Planet")
                    case .drafts:
                        Button {
                            appViewModel.newArticleDraft.toggle()
                        } label: {
                            Image(systemName: "plus")
                        }
                        .help("New Draft")
                    }
                }
                ToolbarTitleMenu {
                    Picker(selection: $appViewModel.selectedTab) {
                        Text(PlanetAppTab.latest.name())
                            .tag(PlanetAppTab.latest)
                        Text(PlanetAppTab.myPlanets.name())
                            .tag(PlanetAppTab.myPlanets)
                        Text(PlanetAppTab.drafts.name())
                            .tag(PlanetAppTab.drafts)
                    } label: {
                        Text(appViewModel.selectedTab.name())
                    }
                }
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .sheet(isPresented: $appViewModel.showSettings) {
            PlanetSettingsView()
                .environmentObject(appViewModel)
                .environmentObject(settingsViewModel)
        }
        .fullScreenCover(isPresented: $appViewModel.newArticle) {
            PlanetNewArticleView(withDraft: nil)
                .environmentObject(appViewModel)
        }
        .fullScreenCover(isPresented: $appViewModel.newArticleDraft) {
            PlanetNewDraftView()
                .environmentObject(appViewModel)
        }
        .fullScreenCover(isPresented: $appViewModel.resumeNewArticle) {
            if let draft = appViewModel.resumedArticleDraft {
                PlanetNewArticleView(withDraft: draft)
                    .environmentObject(appViewModel)
            }
        }
        .sheet(isPresented: $appViewModel.newPlanet) {
            PlanetNewPlanetView()
        }
        .alert(isPresented: $appViewModel.failedToReload) {
            Alert(
                title: Text("Failed to Reload"),
                message: Text(appViewModel.failedMessage),
                dismissButton: .default(Text("Dismiss"))
            )
        }
        .alert(isPresented: $appViewModel.failedToCreateArticle) {
            Alert(
                title: Text("Failed to Create Article"),
                message: Text(appViewModel.failedMessage),
                dismissButton: .default(Text("Dismiss"))
            )
        }
        .alert(isPresented: $isServerInactive) {
            Alert(
                title: Text("Server Inactive"),
                message: Text("Would you like to check for server status in settings?"),
                primaryButton: .default(Text("Open Settings")) {
                    Task { @MainActor in
                        self.appViewModel.showSettings.toggle()
                    }
                },
                secondaryButton: .cancel(Text("Not Now"))
            )
        }
    }

    private func navigationTitle() -> String {
        var name = appViewModel.selectedTab.name()
        if appViewModel.currentServerName.count > 0 {
            let serverName = appViewModel.currentServerName
            name += " · \(serverName)"
        }
        return name
    }
    
    private func checkServerStatus() {
        Task.detached(priority: .background) {
            Task { @MainActor in
                self.serverStatus = await PlanetStatus.shared.serverIsOnline()
            }
        }
    }
}
