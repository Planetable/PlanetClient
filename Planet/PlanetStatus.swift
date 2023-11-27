import Foundation
import SwiftUI


actor PlanetStatus {
    static let shared = PlanetStatus()

    let settingsViewModel = PlanetSettingsViewModel()

    // MARK: TODO: cached server status for 5 seconds
    private var cachedServerStatus: Bool = false {
        willSet {

        }
        didSet {

        }
    }

    func serverIsOnline() async -> Bool {
        let serverURL = settingsViewModel.serverURL
        let serverAuthenticationEnabled = settingsViewModel.serverAuthenticationEnabled
        let serverUsername = settingsViewModel.serverUsername
        let serverPassword = settingsViewModel.serverPassword
        if let url = URL(string: serverURL) {
            let requestIdURL = url.appending(path: "/v0/id")
            let data = try? Data(contentsOf: requestIdURL)
            if let data = data, let currentNodeID = String(data: data, encoding: .utf8) {
                Task { @MainActor in
                    PlanetAppViewModel.shared.currentNodeID = currentNodeID
                }
                debugPrint("👌 Connected. Current Node ID is: \(currentNodeID)")
            }
            var request = URLRequest(
                url: url.appending(path: "/v0/planets/my"),
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
                self.settingsViewModel.updatePreviousServerURL(url)
                self.settingsViewModel.updatePreviousServerStatus(status)
                return status
            } catch {
                debugPrint("failed to get node id: \(error)")
            }
        }
        self.settingsViewModel.resetPreviousServerInfo()
        return false
    }
}
