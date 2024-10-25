//
//  PlanetApp.swift
//  Planet
//
//  Created by Kai on 2/16/23.
//

import SwiftUI

@main
struct PlanetApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var appViewModel: PlanetAppViewModel
    @StateObject private var settingsViewModel: PlanetSettingsViewModel

    init() {
        _appViewModel = StateObject(wrappedValue: PlanetAppViewModel.shared)
        _settingsViewModel = StateObject(wrappedValue: PlanetSettingsViewModel.shared)
    }

    var body: some Scene {
        WindowGroup {
            PlanetAppView()
                .environmentObject(appViewModel)
                .environmentObject(settingsViewModel)
                .onChange(of: scenePhase) { scenePhase in
                    if scenePhase == .active {
                        NotificationCenter.default.post(name: .updateServerStatus, object: nil)
                    }
                }
        }
    }
}
