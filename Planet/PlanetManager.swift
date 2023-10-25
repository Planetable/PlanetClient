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
    
    func basicAuthenticationValue(username: String, password: String) throws -> String {
        let loginString = "\(username):\(password)"
        guard let loginData = loginString.data(using: .utf8) else {
            throw NSError.serverAuthenticationInvalid
        }
        let base64LoginString = loginData.base64EncodedString()
        return "Basic \(base64LoginString)"
    }
    
    // MARK: - API Methods -
    // MARK: - list my planets
    func getMyPlanets() async throws -> [Planet] {
        guard await PlanetSettingsViewModel.shared.serverIsOnline() else { throw NSError.serverIsInactive }
        let serverURL = PlanetSettingsViewModel.shared.serverURL
        let serverAuthenticationEnabled = PlanetSettingsViewModel.shared.serverAuthenticationEnabled
        let url = URL(string: serverURL)!.appendingPathComponent("/v0/planets/my")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        if serverAuthenticationEnabled {
            let serverUsername = PlanetSettingsViewModel.shared.serverUsername
            let serverPassword = PlanetSettingsViewModel.shared.serverPassword
            let loginValue = try? PlanetManager.shared.basicAuthenticationValue(username: serverUsername, password: serverPassword)
            request.setValue(loginValue, forHTTPHeaderField: "Authorization")
        }
        let (data, _) = try await URLSession.shared.data(for: request)
        let decoder = JSONDecoder()
        return try decoder.decode([Planet].self, from: data)
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
            let serverUsername = PlanetSettingsViewModel.shared.serverUsername
            let serverPassword = PlanetSettingsViewModel.shared.serverPassword
            let loginValue = try? PlanetManager.shared.basicAuthenticationValue(username: serverUsername, password: serverPassword)
            request.setValue(loginValue, forHTTPHeaderField: "Authorization")
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
    
    // MARK: - list my articles
    func getMyArticles() async throws -> [PlanetArticle] {
        guard await PlanetSettingsViewModel.shared.serverIsOnline() else { throw NSError.serverIsInactive }
        var planets = PlanetMyPlanetsViewModel.shared.myPlanets
        if planets.count == 0 {
            planets = try await getMyPlanets()
        }
        let planetIDs: [String] = planets.map() { p in
            return p.id
        }
        guard planetIDs.count > 0 else { return [] }
        guard await PlanetSettingsViewModel.shared.serverIsOnline() else { throw NSError.serverIsInactive }
        let serverURL = PlanetSettingsViewModel.shared.serverURL
        let serverAuthenticationEnabled = PlanetSettingsViewModel.shared.serverAuthenticationEnabled
        return await withTaskGroup(of: [PlanetArticle].self, body: { group in
            var articles: [PlanetArticle] = []
            // fetch articles from different planets inside task group.
            for planetID in planetIDs {
                let url = URL(string: serverURL)!.appendingPathComponent("/v0/planets/my/\(planetID)/articles")
                group.addTask {
                    do {
                        var request = URLRequest(url: url)
                        if serverAuthenticationEnabled {
                            let serverUsername = PlanetSettingsViewModel.shared.serverUsername
                            let serverPassword = PlanetSettingsViewModel.shared.serverPassword
                            let loginValue = try? PlanetManager.shared.basicAuthenticationValue(username: serverUsername, password: serverPassword)
                            request.setValue(loginValue, forHTTPHeaderField: "Authorization")
                        }
                        let (data, _) = try await URLSession.shared.data(for: request)
                        let decoder = JSONDecoder()
                        let planetArticles: [PlanetArticle] = try decoder.decode([PlanetArticle].self, from: data)
                        return planetArticles.map() { p in
                            var t = p
                            t.planetID = UUID(uuidString: planetID)
                            return t
                        }
                    } catch {
                        debugPrint("failed to fetch articles for planet: \(planetID), error: \(error)")
                        return []
                    }
                }
            }
            for await items in group {
                articles.append(contentsOf: items)
            }
            return articles
        })
    }
    
    // MARK: - create article
    func createArticle(title: String, content: String, attachments: [PlanetArticleAttachment], forPlanet planet: Planet) async throws {
        guard await PlanetSettingsViewModel.shared.serverIsOnline() else { throw NSError.serverIsInactive }
        let serverURL = PlanetSettingsViewModel.shared.serverURL
        let serverAuthenticationEnabled = PlanetSettingsViewModel.shared.serverAuthenticationEnabled
        let url = URL(string: serverURL)!.appendingPathComponent("/v0/planets/my/\(planet.id)/articles")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        if serverAuthenticationEnabled {
            let serverUsername = PlanetSettingsViewModel.shared.serverUsername
            let serverPassword = PlanetSettingsViewModel.shared.serverPassword
            let loginValue = try? PlanetManager.shared.basicAuthenticationValue(username: serverUsername, password: serverPassword)
            request.setValue(loginValue, forHTTPHeaderField: "Authorization")
        }
        var form: MultipartForm = MultipartForm(parts: [
            MultipartForm.Part(name: "title", value: title),
            MultipartForm.Part(name: "date", value: Date().description),
            MultipartForm.Part(name: "content", value: content)
        ])
        for attachment in attachments {
            let attachmentName = attachment.url.lastPathComponent
            let attachmentContentType = attachment.url.mimeType()
            let attachmentData = try Data(contentsOf: attachment.url)
            let formData = MultipartForm.Part(name: "attachment", data: attachmentData, filename: attachmentName, contentType: attachmentContentType)
            form.parts.append(formData)
            debugPrint("Create Article: attachment: \(attachmentName), contentType: \(attachmentContentType)")
        }
        debugPrint("Create Article: title: \(title), content: \(content) with \(attachments.count) attachments.")
        request.setValue(form.contentType, forHTTPHeaderField: "Content-Type")
        let (_, response) = try await URLSession.shared.upload(for: request, from: form.bodyData)
        let statusCode = (response as! HTTPURLResponse).statusCode
        if statusCode == 200 {
            try? await Task.sleep(for: .seconds(2))
            await MainActor.run {
                NotificationCenter.default.post(name: .reloadArticles, object: nil)
            }
        }
    }
}
