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

    private func createRequest(with path: String, method: String) async throws -> URLRequest {
        guard await PlanetSettingsViewModel.shared.serverIsOnline() else { throw PlanetError.PublicAPIServerIsInactive }
        let serverURL = PlanetSettingsViewModel.shared.serverURL
        let url = URL(string: serverURL)!.appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.httpMethod = method
        if PlanetSettingsViewModel.shared.serverAuthenticationEnabled {
            let serverUsername = PlanetSettingsViewModel.shared.serverUsername
            let serverPassword = PlanetSettingsViewModel.shared.serverPassword
            let loginValue = try? basicAuthenticationValue(username: serverUsername, password: serverPassword)
            request.setValue(loginValue, forHTTPHeaderField: "Authorization")
        }
        return request
    }

    func basicAuthenticationValue(username: String, password: String) throws -> String {
        let loginString = "\(username):\(password)"
        guard let loginData = loginString.data(using: .utf8) else {
            throw PlanetError.PublicAPIServerAuthenticationInvalid
        }
        let base64LoginString = loginData.base64EncodedString()
        return "Basic \(base64LoginString)"
    }

    func getPlanetPath(forID planetID: String) -> URL? {
        guard let nodeID = PlanetAppViewModel.shared.currentNodeID else {
            return nil
        }
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let myPlanetPath = documentsDirectory.appendingPathComponent(nodeID).appendingPathComponent("My").appendingPathComponent(planetID)
        if FileManager.default.fileExists(atPath: myPlanetPath.path) == false {
            try? FileManager.default.createDirectory(at: myPlanetPath, withIntermediateDirectories: true, attributes: nil)
            debugPrint("Folder created at path: \(myPlanetPath.path)")
        }
        return myPlanetPath
    }

    func getPlanetArticlesPath(forID planetID: String) -> URL? {
        guard let _ = PlanetAppViewModel.shared.currentNodeID else {
            return nil
        }
        let planetPath = getPlanetPath(forID: planetID)
        let myPlanetArticlesPath = planetPath?.appendingPathComponent("articles.json")
        return myPlanetArticlesPath
    }

    // MARK: - API Methods -
    // MARK: - list my planets
    func getMyPlanets() async throws -> [Planet] {
        let request = try await createRequest(with: "/v0/planets/my", method: "GET")
        let (data, _) = try await URLSession.shared.data(for: request)
        let decoder = JSONDecoder()
        let planets = try decoder.decode([Planet].self, from: data)
        // Save planets to:
        // /Documents/:node_id/My/:planet_id/planet.json
        for planet in planets {
            if let planetPath = getPlanetPath(forID: planet.id) {
                let encoder = JSONEncoder()
                encoder.outputFormatting = .prettyPrinted
                let data = try encoder.encode(planet)
                try data.write(to: planetPath.appendingPathComponent("planet.json"))
            }
        }
        return planets
    }
    
    // MARK: - create planet
    func createPlanet(name: String, about: String, avatarPath: String) async throws {
        var request = try await createRequest(with: "/v0/planets/my", method: "POST")
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

    // MARK: - modify planet
    func modifyPlanet(id: String, name: String, about: String, avatarPath: String) async throws {
        var request = try await createRequest(with: "/v0/planets/my/\(id)", method: "POST")
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
            var shouldReloadAvatar: Bool = false
            if avatarPath != "", let planetPath = getPlanetPath(forID: id) {
                shouldReloadAvatar = true
                let planetAvatarPath = planetPath.appendingPathComponent("avatar.png")
                if FileManager.default.fileExists(atPath: planetAvatarPath.path) {
                    try? FileManager.default.removeItem(at: planetAvatarPath)
                    try? FileManager.default.copyItem(at: URL(fileURLWithPath: avatarPath), to: planetAvatarPath)
                }
            }
            try? await Task.sleep(for: .seconds(2))
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .updatePlanets, object: nil)
            }
            if shouldReloadAvatar {
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .reloadAvatar(byID: id), object: nil)
                }
            }
        }
    }

    // MARK: - delete planet
    func deletePlanet(id: String) async throws {
        let request = try await createRequest(with: "/v0/planets/my/\(id)", method: "DELETE")
        let (_, response) = try await URLSession.shared.data(for: request)
        let statusCode = (response as! HTTPURLResponse).statusCode
        if statusCode == 200 {
            try? await Task.sleep(for: .seconds(2))
            await MainActor.run {
                NotificationCenter.default.post(name: .updatePlanets, object: nil)
            }
            try? await Task.sleep(for: .seconds(1))
            guard let nodeID = PlanetAppViewModel.shared.currentNodeID else { return }
            let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let planetPath = documentsDirectory.appendingPathComponent(nodeID).appendingPathComponent("My").appendingPathComponent(id)
            try? FileManager.default.removeItem(at: planetPath)
        }
    }

    // MARK: - list my articles
    func getMyArticles() async throws -> [PlanetArticle] {
        var planets = PlanetMyPlanetsViewModel.shared.myPlanets
        if planets.count == 0 {
            planets = try await getMyPlanets()
        }
        let planetIDs: [String] = planets.map() { p in
            return p.id
        }
        guard planetIDs.count > 0 else { return [] }
        return await withTaskGroup(of: [PlanetArticle].self, body: { group in
            var articles: [PlanetArticle] = []
            // fetch articles from different planets inside task group.
            for planetID in planetIDs {
                group.addTask {
                    do {
                        let request = try await self.createRequest(with: "/v0/planets/my/\(planetID)/articles", method: "GET")
                        let (data, _) = try await URLSession.shared.data(for: request)
                        let decoder = JSONDecoder()
                        let planetArticles: [PlanetArticle] = try decoder.decode([PlanetArticle].self, from: data)
                        let result = planetArticles.map() { p in
                            var t = p
                            t.planetID = UUID(uuidString: planetID)
                            return t
                        }
                        // Save articles to:
                        // /Documents/:node_id/My/:planet_id/articles.json
                        if let articlesPath = self.getPlanetArticlesPath(forID: planetID) {
                            let encoder = JSONEncoder()
                            encoder.outputFormatting = .prettyPrinted
                            let data = try encoder.encode(result)
                            try data.write(to: articlesPath)
                            debugPrint("Saved articles to path: \(articlesPath.path)")
                        }
                        return result
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
        var request = try await createRequest(with: "/v0/planets/my/\(planet.id)/articles", method: "POST")
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
