//
//  PlanetSettingsViewModel.swift
//  Planet
//
//  Created by Kai on 2/18/23.
//

import Foundation
import KeychainSwift
import SwiftUI

class PlanetSettingsViewModel: ObservableObject {
    static let shared = PlanetSettingsViewModel()

    let timer = Timer.publish(every: 2.5, on: .main, in: .common).autoconnect()

    private var previousURL: URL?
    private var previousStatus: Bool = false

    @Published var serverURL: String =
        UserDefaults.standard.string(forKey: .settingsServerURLKey) ?? ""
    {
        didSet {
            resetPreviousServerInfo()
            Task(priority: .background) {
                if await self.serverIsOnline() {
                    UserDefaults.standard.set(self.serverURL, forKey: .settingsServerURLKey)
                }
            }
        }
    }
    @Published var serverAuthenticationEnabled: Bool = UserDefaults.standard.bool(
        forKey: .settingsServerAuthenticationEnabledKey
    )
    {
        didSet {
            resetPreviousServerInfo()
            UserDefaults.standard.set(
                serverAuthenticationEnabled,
                forKey: .settingsServerAuthenticationEnabledKey
            )
        }
    }
    @Published var serverUsername: String =
        UserDefaults.standard.string(forKey: .settingsServerUsernameKey) ?? ""
    {
        didSet {
            resetPreviousServerInfo()
            UserDefaults.standard.set(serverUsername, forKey: .settingsServerUsernameKey)
        }
    }
    @Published var serverPassword: String = "" {
        didSet {
            resetPreviousServerInfo()
            let keychain = KeychainSwift()
            keychain.set(serverPassword, forKey: .settingsServerPasswordKey)
        }
    }
    @Published var validatingServerStatus: Bool = false

    init() {
        debugPrint("Settings View Model Init.")
        let keychain = KeychainSwift()
        if let password = keychain.get(.settingsServerPasswordKey) {
            serverPassword = password
        }
    }

    func resetPreviousServerInfo() {
        previousURL = nil
        previousStatus = false
    }

    func serverIsOnline() async -> Bool {
        if let url = URL(string: serverURL) {
            if let previousURL, previousURL == url, previousStatus {
                return previousStatus
            }
            let requestIdURL = url.appendingPathComponent("/v0/id")
            let data = try? Data(contentsOf: requestIdURL)
            if let data = data, let currentNodeID = String(data: data, encoding: .utf8) {
                Task { @MainActor in
                    PlanetAppViewModel.shared.currentNodeID = currentNodeID
                }
                debugPrint("Current Node ID is: \(currentNodeID)")
            }
            var request = URLRequest(
                url: url.appendingPathComponent("/v0/planets/my"),
                cachePolicy: .reloadIgnoringCacheData,
                timeoutInterval: 5
            )
            request.httpMethod = "GET"
            if serverAuthenticationEnabled {
                let loginValue = try? PlanetManager.shared.basicAuthenticationValue(
                    username: serverUsername,
                    password: serverPassword
                )
                request.setValue(loginValue, forHTTPHeaderField: "Authorization")
            }
            do {
                let (_, response) = try await URLSession.shared.data(for: request)
                let responseStatusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
                let status = responseStatusCode == 200
                previousStatus = status
                previousURL = url
                return status
            }
            catch {
                resetPreviousServerInfo()
            }
        }
        else {
            resetPreviousServerInfo()
        }
        return false
    }
}
