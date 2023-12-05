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

    let timer = Timer.publish(every: 5, on: .main, in: .common).autoconnect()

    @Published var showServerUnreachableAlert = false
    @Published var isConnecting: Bool = false

    @Published var serverURLString: String =
        UserDefaults.standard.string(forKey: .settingsServerURLKey) ?? ""
    @Published var serverProtocol: String =
        UserDefaults.standard.string(forKey: .settingsServerProtocolKey) ?? "http"
    @Published var serverHost: String =
        UserDefaults.standard.string(forKey: .settingsServerHostKey) ?? ""
    @Published var serverPort: String =
        UserDefaults.standard.string(forKey: .settingsServerPortKey) ?? "8086"
    @Published var serverAuthenticationEnabled: Bool = UserDefaults.standard.bool(
        forKey: .settingsServerAuthenticationEnabledKey
    )
    @Published var serverUsername: String =
        UserDefaults.standard.string(forKey: .settingsServerUsernameKey) ?? ""
    @Published var serverPassword: String = ""

    init() {
        debugPrint("Settings View Model Init.")
        if let password = try? KeychainHelper.shared.loadValue(forKey: .settingsServerPasswordKey) {
            serverPassword = password
        }
    }
    
    func getServerURLString() -> String? {
        if serverProtocol.isEmpty || serverHost.isEmpty {
            return nil
        }
        var url = serverProtocol + "://" + serverHost
        if !serverPort.isEmpty {
            url += ":" + serverPort
        }
        return url
    }

    /// Try to connect with the info provided by user.
    /// If connected, save the info to disk.
    func saveAndConnect() async {
        guard let serverURLString = getServerURLString() else { return }
        Task { @MainActor in
            self.isConnecting = true
        }
        Task(priority: .userInitiated) {
            let status: Bool = await checkServerStatus()
            Task { @MainActor in
                self.isConnecting = false
            }
            if status == true {
                debugPrint("connected to server: \(serverURLString)")
                saveSettings()
                Task { @MainActor in
                    PlanetAppViewModel.shared.showSettings = false
                }
            } else {
                debugPrint("failed to connect to server: \(serverURLString)")
                Task { @MainActor in
                    self.showServerUnreachableAlert = true
                }
            }
        }
    }

    func getServerInfo() async -> PlanetServerInfo? {
        guard let serverURLString = getServerURLString() else { return nil }
        guard let url = URL(string: serverURLString) else {
            debugPrint("invalid server url: \(serverURLString)")
            return nil
        }
        debugPrint("getting server info: \(url)")
        var request = URLRequest(
            url: url.appending(path: "/v0/info"),
            cachePolicy: .reloadIgnoringCacheData,
            timeoutInterval: 5
        )
        request.httpMethod = "GET"
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let info = try JSONDecoder().decode(PlanetServerInfo.self, from: data)
            return info
        } catch {
            debugPrint("failed to get server info: \(error)")
        }
        return nil
    }

    func checkServerStatus() async -> Bool {
        guard let serverURLString = getServerURLString() else { return false }
        guard let url = URL(string: serverURLString) else {
            debugPrint("invalid server url: \(serverURLString)")
            return false
        }
        debugPrint("checking server status: \(url)")
        var request = URLRequest(
            url: url.appending(path: "/v0/ping"),
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
            let status: Bool = responseStatusCode == 200
            if status == true {
                /// Server is online
                if let info: PlanetServerInfo = await getServerInfo() {
                    debugPrint("👌 got server info: \(info.ipfsPeerID)")
                    Task { @MainActor in
                        if PlanetAppViewModel.shared.currentNodeID != info.ipfsPeerID {
                            PlanetAppViewModel.shared.currentNodeID = info.ipfsPeerID
                        }
                    }
                    return true
                } else {
                    return false
                }
            } else {
                /// Server is offline
                return false
            }
        } catch {
            debugPrint("failed to ping node: \(error)")
        }
        return false
    }

    func saveSettings() {
        guard let serverURLString = getServerURLString() else { return }
        debugPrint("saving new server: \(serverURLString)")
        Task { @MainActor in
            PlanetAppViewModel.shared.currentServerURLString = serverURLString
        }
        UserDefaults.standard.set(serverURLString, forKey: .settingsServerURLKey)
        UserDefaults.standard.set(serverProtocol, forKey: .settingsServerProtocolKey)
        UserDefaults.standard.set(serverHost, forKey: .settingsServerHostKey)
        UserDefaults.standard.set(serverPort, forKey: .settingsServerPortKey)
        UserDefaults.standard.set(
            serverAuthenticationEnabled,
            forKey: .settingsServerAuthenticationEnabledKey
        )
        UserDefaults.standard.set(serverUsername, forKey: .settingsServerUsernameKey)
        do {
            try KeychainHelper.shared.saveValue(serverPassword, forKey: .settingsServerPasswordKey)
        } catch {
            debugPrint("failed to save server password into keychain: \(error)")
        }
        debugPrint("saved new server: \(serverURLString)")
    }

    func resetLocalCache() async {
        debugPrint("resetting local cache")
        do {
            try await PlanetManager.shared.resetLocalCache()
        } catch {
            debugPrint("failed to reset local cache: \(error)")
        }
    }
}
