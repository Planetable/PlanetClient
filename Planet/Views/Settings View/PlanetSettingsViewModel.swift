//
//  PlanetSettingsViewModel.swift
//  Planet
//
//  Created by Kai on 2/18/23.
//

import Foundation
import SwiftUI


class PlanetSettingsViewModel: ObservableObject {
    static let shared = PlanetSettingsViewModel()
    
    let timer = Timer.publish(every: 2.5, on: .main, in: .common).autoconnect()
    
    private var previousURL: URL?
    private var previousStatus: Bool = false

    @Published var serverURL: String = UserDefaults.standard.string(forKey: .settingsServerURLKey) ?? "" {
        didSet {
            if !serverURL.hasPrefix("http") {
                UserDefaults.standard.set("http://" + serverURL, forKey: .settingsServerURLKey)
            }
            previousURL = nil
        }
    }
    @Published var serverAuthenticationEnabled: Bool = UserDefaults.standard.bool(forKey: .settingsServerAuthenticationEnabledKey) {
        didSet {
            UserDefaults.standard.set(serverAuthenticationEnabled, forKey: .settingsServerAuthenticationEnabledKey)
        }
    }
    @Published var serverUsername: String = UserDefaults.standard.string(forKey: .settingsServerUsernameKey) ?? "" {
        didSet {
            UserDefaults.standard.set(serverUsername, forKey: .settingsServerUsernameKey)
        }
    }
    // MARK: TODO: store in keychain
    @Published var serverPassword: String = UserDefaults.standard.string(forKey: .settingsServerPasswordKey) ?? "" {
        didSet {
            UserDefaults.standard.set(serverPassword, forKey: .settingsServerPasswordKey)
        }
    }
    @Published var validatingServerStatus: Bool = false

    init() {
        debugPrint("Settings View Model Init.")
    }
    
    // MARK: TODO: authentication
    func serverIsOnline() async -> Bool {
        if let url = URL(string: serverURL) {
            if let previousURL, previousURL == url, previousStatus {
                return previousStatus
            }
            debugPrint("validating server status...")
            var request = URLRequest(url: url, cachePolicy: .reloadIgnoringCacheData, timeoutInterval: 1)
            request.httpMethod = "HEAD"
            do {
                let (_, response) = try await URLSession.shared.data(for: request)
                let responseStatusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
                let status = responseStatusCode == 404
                previousStatus = status
                previousURL = url
                return status
            } catch {
                previousStatus = false
                previousURL = nil
                debugPrint("failed to validate server status: \(error), will retry in 5 seconds...")
            }
        } else {
            previousStatus = false
            previousURL = nil
        }
        return false
    }
}
