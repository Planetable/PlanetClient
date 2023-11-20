import SwiftUI


struct PlanetMainView: View {
    @EnvironmentObject private var appViewModel: PlanetAppViewModel
    @EnvironmentObject private var latestViewModel: PlanetLatestViewModel
    @EnvironmentObject private var myPlanetsViewModel: PlanetMyPlanetsViewModel
    @EnvironmentObject private var settingsViewModel: PlanetSettingsViewModel

    var body: some View {
        NavigationStack(path: $appViewModel.path) {
            VStack {
                switch appViewModel.selectedTab {
                case .latest:
                    PlanetLatestView()
                        .environmentObject(appViewModel)
                        .environmentObject(latestViewModel)
                        .environmentObject(myPlanetsViewModel)
                default:
                    PlanetMyPlanetsView()
                        .environmentObject(appViewModel)
                        .environmentObject(myPlanetsViewModel)
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
                            Text("New Article")
                        }
                        Button {
                            appViewModel.newPlanet.toggle()
                        } label: {
                            Text("New Planet")
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
        .sheet(isPresented: $appViewModel.newArticle) {
            PlanetNewArticleView()
                .environmentObject(myPlanetsViewModel)
        }
        .sheet(isPresented: $appViewModel.newPlanet) {
            PlanetNewPlanetView()
        }
    }
}
