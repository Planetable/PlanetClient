//
//  PlanetApp.swift
//  Planet
//
//  Created by Kai on 2/16/23.
//

import SwiftUI

@main
struct PlanetApp: App {
    @UIApplicationDelegateAdaptor(PlanetAppDelegate.self) var appDelegate
    
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
        }
    }
}

class PlanetAppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        debugPrint("App did finish launching with options: \(launchOptions)")
        return true
    }
}
