import SwiftUI


struct PlanetAppView: View {
    @EnvironmentObject private var appViewModel: PlanetAppViewModel
    @EnvironmentObject private var settingsViewModel: PlanetSettingsViewModel

    @State private var serverStatus: Bool = true
    @State private var isWaitingUpdate: Bool = false

    var body: some View {
        NavigationStack(path: $appViewModel.path) {
            VStack {
                if isWaitingUpdate {
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Updating post in background")
                            .font(.footnote)
                    }
                    .foregroundStyle(Color.secondary)
                    .ignoresSafeArea(edges: .horizontal)
                    .padding(.bottom, -6)
                }
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
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        appViewModel.showSettings.toggle()
                    } label: {
                        Image(systemName: "gear")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    switch appViewModel.selectedTab {
                    case .latest:
                        Button {
                            appViewModel.newArticle.toggle()
                        } label: {
                            Image(systemName: "plus")
                        }
                        .disabled(!serverStatus)
                        .help("New Article")
                    case .myPlanets:
                        Button {
                            appViewModel.newPlanet.toggle()
                        } label: {
                            Image(systemName: "plus")
                        }
                        .disabled(!serverStatus)
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
        .onReceive(settingsViewModel.timer) { _ in
            Task { @MainActor in
                self.serverStatus = await PlanetStatus.shared.serverIsOnline()
                let allKeys = UserDefaults.standard.dictionaryRepresentation().keys
                let waitingStatus = allKeys.filter({ $0.hasPrefix("PlanetEditingArticleKey-") }).count > 0
                withAnimation {
                    self.isWaitingUpdate = waitingStatus
                }
            }
        }
        .task(priority: .utility) {
            self.serverStatus = await PlanetStatus.shared.serverIsOnline()
        }
        .alert(isPresented: $appViewModel.failedToReload) {
            Alert(
                title: Text("Failed to Reload"),
                message: Text(appViewModel.failedMessage),
                dismissButton: .default(Text("Dismiss"))
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
}
