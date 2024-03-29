//
//  PlanetApp.swift
//  Planet
//
//  Created by Kai on 2/16/23.
//

import SwiftUI

@main
struct PlanetApp: App {
    @StateObject private var appViewModel: PlanetAppViewModel
    @StateObject private var settingsViewModel: PlanetSettingsViewModel

    @Environment(\.scenePhase) private var phase

    init() {
        _appViewModel = StateObject(wrappedValue: PlanetAppViewModel.shared)
        _settingsViewModel = StateObject(wrappedValue: PlanetSettingsViewModel.shared)
    }

    var body: some Scene {
        WindowGroup {
            PlanetAppView()
                .environmentObject(appViewModel)
                .environmentObject(settingsViewModel)
                .onChange(of: phase) { newValue in
                    switch newValue {
                    case .active:
                        break
                    default:
                        break
                    }
                }
        }
    }
}
