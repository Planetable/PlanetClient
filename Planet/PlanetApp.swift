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
    
    init() {
        _appViewModel = StateObject(wrappedValue: PlanetAppViewModel.shared)
    }
    
    var body: some Scene {
        WindowGroup {
            PlanetAppView()
                .environmentObject(appViewModel)
        }
    }
}

class PlanetAppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        debugPrint("App did finish launching with options: \(launchOptions)")
        return true
    }
}
