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

    private var previousURL: URL?
    private var previousStatus: Bool = false

    @Published var serverURL: String =
        UserDefaults.standard.string(forKey: .settingsServerURLKey) ?? ""
    {
        didSet {
            resetPreviousServerInfo()
            Task(priority: .userInitiated) {
                let status = await PlanetStatus.shared.serverIsOnline()
                if status {
                    UserDefaults.standard.set(self.serverURL, forKey: .settingsServerURLKey)
                }
            }
        }
    }
    @Published var serverProtocol: String =
        UserDefaults.standard.string(forKey: .settingsServerProtocolKey) ?? "http"
    {
        didSet {
            resetPreviousServerInfo()
            UserDefaults.standard.set(serverProtocol, forKey: .settingsServerProtocolKey)
            setServerURL()
        }
    }
    @Published var serverHost: String =
        UserDefaults.standard.string(forKey: .settingsServerHostKey) ?? ""
    {
        didSet {
            resetPreviousServerInfo()
            UserDefaults.standard.set(serverHost, forKey: .settingsServerHostKey)
            setServerURL()
        }
    }
    @Published var serverPort: String =
        UserDefaults.standard.string(forKey: .settingsServerPortKey) ?? "8086"
    {
        didSet {
            resetPreviousServerInfo()
            UserDefaults.standard.set(serverPort, forKey: .settingsServerPortKey)
            setServerURL()
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
            do {
                try KeychainHelper.shared.saveValue(serverPassword, forKey: .settingsServerPasswordKey)
            } catch {
                debugPrint("failed to save server password into keychain: \(error)")
            }
        }
    }

    init() {
        debugPrint("Settings View Model Init.")
        if let password = try? KeychainHelper.shared.loadValue(forKey: .settingsServerPasswordKey) {
            serverPassword = password
        }
    }

    func setServerURL() {
        if serverProtocol.isEmpty || serverHost.isEmpty {
            return
        }
        var url = serverProtocol + "://" + serverHost
        if !serverPort.isEmpty {
            url += ":" + serverPort
        }
        serverURL = url

    }

    func resetPreviousServerInfo() {
        Task { @MainActor in
            previousURL = nil
            previousStatus = false
            // TODO: Implement a multi-server management flow
            // PlanetAppViewModel.shared.currentNodeID = nil
        }
    }

    func updatePreviousServerURL(_ url: URL) {
        previousURL = url
    }

    func updatePreviousServerStatus(_ flag: Bool) {
        previousStatus = flag
    }
}
