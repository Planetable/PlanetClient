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
        if let url = URL(string: serverURLString) {
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
                if status {
                    debugPrint("server (\(serverURLString)) is online.")
                } else {
                    debugPrint("server (\(serverURLString)) is not online.")
                }
                return status
            } catch {}
        }
        debugPrint("server (\(serverURLString)) is not online.")
        return false
    }
}
