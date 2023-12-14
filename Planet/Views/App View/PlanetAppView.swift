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
                    Menu {
                        Button {
                            appViewModel.newArticle.toggle()
                        } label: {
                            Label("New Article", systemImage: "plus")
                        }
                        .disabled(!serverStatus)
                        Button {
                            appViewModel.newPlanet.toggle()
                        } label: {
                            Label("New Planet", systemImage: "plus")
                        }
                        .disabled(!serverStatus)
                        if !serverStatus {
                            Divider()
                            Button {
                                /*
                                    WIP:
                                 */
//                                appViewModel.newArticleDraft.toggle()
                            } label: {
                                Label("New Draft", systemImage: "plus")
                            }
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
                ToolbarTitleMenu {
                    Picker(selection: $appViewModel.selectedTab) {
                        Text(PlanetAppTab.latest.name())
                            .tag(PlanetAppTab.latest)
                        Text(PlanetAppTab.myPlanets.name())
                            .tag(PlanetAppTab.myPlanets)
                        Divider()
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
            PlanetNewArticleView(withDraft: nil, draftMode: false)
                .environmentObject(appViewModel)
        }
        .fullScreenCover(isPresented: $appViewModel.newArticleDraft) {
            PlanetNewArticleView(withDraft: nil, draftMode: true)
                .environmentObject(appViewModel)
        }
        .fullScreenCover(isPresented: $appViewModel.resumeNewArticle) {
            if let draft = appViewModel.resumedArticleDraft {
                PlanetNewArticleView(withDraft: draft, draftMode: false)
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
