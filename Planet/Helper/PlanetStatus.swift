import Foundation
import SwiftUI


actor PlanetStatus {
    static let shared = PlanetStatus()

    let appViewModel = PlanetAppViewModel.shared
    let settingsViewModel = PlanetSettingsViewModel.shared

    func serverIsOnline() async -> Bool {
        let serverURLString = appViewModel.currentServerURLString
        let serverAuthenticationEnabled = settingsViewModel.serverAuthenticationEnabled
        let serverUsername = settingsViewModel.serverUsername
        let serverPassword = settingsViewModel.serverPassword
        debugPrint("checking server online status with url: \(serverURLString)")
        if let url = URL(string: serverURLString) {
            let requestInfoURL = url.appending(path: "/v0/info")
            let data = try? Data(contentsOf: requestInfoURL)
            let info: PlanetServerInfo?
            if let data = data {
                info = try? JSONDecoder().decode(PlanetServerInfo.self, from: data)
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
                if status == true {
                    /// Server is online
                } else {
                    /// Server is offline
                }
                return status
            } catch {
                debugPrint("failed to detect node: \(error)")
            }
        }
        return false
    }
}
