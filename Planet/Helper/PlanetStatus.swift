import Foundation
import SwiftUI


actor PlanetStatus {
    static let shared = PlanetStatus()
    static let key: String = "LastCachedServerStatus"

    let settingsViewModel = PlanetSettingsViewModel.shared

    private var cachedServerStatus: Bool = false
    private var cachedServerDate: Int = Int(Date().timeIntervalSince1970)

    private func cacheIsValid() -> Bool {
        let now = Int(Date().timeIntervalSince1970)
        return now - cachedServerDate < 5
    }

    func serverIsOnline() async -> Bool {
        if cacheIsValid() {
            return cachedServerStatus
        }
        let serverURL = settingsViewModel.serverURL
        let serverAuthenticationEnabled = settingsViewModel.serverAuthenticationEnabled
        let serverUsername = settingsViewModel.serverUsername
        let serverPassword = settingsViewModel.serverPassword
        if let url = URL(string: serverURL) {
            let requestInfoURL = url.appending(path: "/v0/info")
            let data = try? Data(contentsOf: requestInfoURL)
            if let data = data, let info = try? JSONDecoder().decode(PlanetServerInfo.self, from: data) {
                debugPrint("👌 Connected. Current Node ID is: \(info.ipfsPeerID)")
                Task { @MainActor in
                    PlanetAppViewModel.shared.currentNodeID = info.ipfsPeerID
                }
            }
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
                if cachedServerStatus != status, status {
                    Task(priority: .userInitiated) {
                        try? await PlanetAppViewModel.shared.reloadPlanetsAndArticles()
                    }
                }
                self.settingsViewModel.updatePreviousServerURL(url)
                self.settingsViewModel.updatePreviousServerStatus(status)
                self.cachedServerStatus = status
                self.cachedServerDate = Int(Date().timeIntervalSince1970)
                return status
            } catch {
                debugPrint("failed to get node id: \(error)")
            }
        }
        self.settingsViewModel.resetPreviousServerInfo()
        return false
    }
}
