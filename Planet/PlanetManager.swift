//
//  PlanetManager.swift
//  Planet
//
//  Created by Kai on 2/19/23.
//

import Foundation


class PlanetManager: NSObject {
    static let shared = PlanetManager()
    
    private override init() {
        debugPrint("Planet Manager Init.")
    }
    
    func setup() {
    }
    
    // MARK: - API Methods
    func getMyPlanets() async throws -> [Planet] {
        guard await PlanetSettingsViewModel.shared.serverIsOnline() else { throw NSError.serverIsInactive }
        let serverURL = PlanetSettingsViewModel.shared.serverURL
        let serverAuthenticationEnabled = PlanetSettingsViewModel.shared.serverAuthenticationEnabled
        let url = URL(string: serverURL)!.appendingPathComponent("/v0/planets/my")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        if serverAuthenticationEnabled {
            // Basic Authentication
            let serverUsername = PlanetSettingsViewModel.shared.serverUsername
            let serverPassword = PlanetSettingsViewModel.shared.serverPassword
        }
        let (data, _) = try await URLSession.shared.data(for: request)
        let decoder = JSONDecoder()
        let planets = try decoder.decode([Planet].self, from: data)
        return planets
    }
}
