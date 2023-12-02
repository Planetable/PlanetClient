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
                default:
                    PlanetMyPlanetsView()
                        .environmentObject(appViewModel)
                }
            }
            .navigationTitle(appViewModel.selectedTab.name())
            .navigationBarTitleDisplayMode(.inline)
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
            PlanetNewArticleView()
                .environmentObject(appViewModel)
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
    }
}
