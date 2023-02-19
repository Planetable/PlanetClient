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
    // MARK: - list my planets
    func getMyPlanets() async throws -> [Planet] {
        guard await PlanetSettingsViewModel.shared.serverIsOnline() else { throw NSError.serverIsInactive }
        let serverURL = PlanetSettingsViewModel.shared.serverURL
        let serverAuthenticationEnabled = PlanetSettingsViewModel.shared.serverAuthenticationEnabled
        let url = URL(string: serverURL)!.appendingPathComponent("/v0/planets/my")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        if serverAuthenticationEnabled {
            // Basic Authentication
        }
        let (data, _) = try await URLSession.shared.data(for: request)
        let decoder = JSONDecoder()
        let planets = try decoder.decode([Planet].self, from: data)
        return planets
    }
    
    // MARK: - create planet
    func createPlanet(name: String, about: String, avatarPath: String) async throws {
        guard await PlanetSettingsViewModel.shared.serverIsOnline() else { throw NSError.serverIsInactive }
        let serverURL = PlanetSettingsViewModel.shared.serverURL
        let serverAuthenticationEnabled = PlanetSettingsViewModel.shared.serverAuthenticationEnabled
        let url = URL(string: serverURL)!.appendingPathComponent("/v0/planets/my")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        if serverAuthenticationEnabled {
            // Basic Authentication
        }
        let form: MultipartForm
        if avatarPath != "" {
            let url = URL(fileURLWithPath: avatarPath)
            let imageName = url.lastPathComponent
            let contentType = url.mimeType()
            let data = try Data(contentsOf: url)
            form = MultipartForm(parts: [
                MultipartForm.Part(name: "name", value: name),
                MultipartForm.Part(name: "about", value: about),
                MultipartForm.Part(name: "avatar", data: data, filename: imageName, contentType: contentType)
            ])
        } else {
            form = MultipartForm(parts: [
                MultipartForm.Part(name: "name", value: name),
                MultipartForm.Part(name: "about", value: about)
            ])
        }
        request.setValue(form.contentType, forHTTPHeaderField: "Content-Type")
        let (_, response) = try await URLSession.shared.upload(for: request, from: form.bodyData)
        let statusCode = (response as! HTTPURLResponse).statusCode
        if statusCode == 200 {
            try? await Task.sleep(for: .seconds(2))
            await MainActor.run {
                NotificationCenter.default.post(name: .updatePlanets, object: nil)
            }
        }
    }
}
