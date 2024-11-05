//
//  PlanetManager.swift
//  Planet
//
//  Created by Kai on 2/19/23.
//

import Foundation
import UIKit
import PlanetSiteTemplates
import Stencil
import PathKit

class PlanetManager: NSObject {
    static let shared = PlanetManager()

    var templates: [BuiltInTemplate] = []
    var documentDirectory: URL
    var draftsDirectory: URL
    var previewTemplatePath: URL
    var previewRenderEnv: Environment

    // Shared user defaults for share extension.
    // Setup app group identifier first.
    var userDefaults: UserDefaults {
        if let defaults = UserDefaults(suiteName: .appGroupName) {
            return defaults
        }
        return .standard
    }

    private override init() {
        debugPrint("Planet Manager Init.")
//        guard let documentPath: URL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
//            fatalError("can't access to document directory, abort init.")
//        }
        guard let documentPath: URL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: .appGroupName) else {
            fatalError("can't access to document directory, abort init.")
        }
        documentDirectory = documentPath
        draftsDirectory = documentDirectory.appending(path: "Drafts")
        do {
            if !FileManager.default.fileExists(atPath: draftsDirectory.path) {
                try FileManager.default.createDirectory(at: draftsDirectory, withIntermediateDirectories: true)
            }
        } catch {
            fatalError("can't create drafts directory, abort init.")
        }
        guard let path = Bundle.main.url(forResource: "WriterBasic", withExtension: "html") else {
            fatalError("preview template not loaded, abort init.")
        }
        previewTemplatePath = path
        previewRenderEnv = Environment(loader: FileSystemLoader(paths: [Path(previewTemplatePath.path)]), extensions: [StencilExtension.common])
        super.init()
        Task(priority: .utility) {
            self.templates = PlanetSiteTemplates.builtInTemplates
            for template in self.templates {
                debugPrint("template: \(template.name), loaded at: \(template.assets)")
            }
        }
    }

    // MARK: -
    func createRequest(with path: String, method: String) async throws -> URLRequest {
        guard await PlanetStatus.shared.serverIsOnline() else { throw PlanetError.APIServerIsInactiveError }
        guard let serverURL = URL(string: PlanetAppViewModel.shared.currentServerURLString) else {
            throw PlanetError.APIServerError
        }
        let url = serverURL.appending(path: path)
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

    func downloadPlanetAvatar(planetID: String) async throws {
        guard let serverURL = URL(string: PlanetAppViewModel.shared.currentServerURLString), let planetPath = getPlanetPath(forID: planetID) else {
            return
        }
        let remoteAvatarURL = serverURL
            .appending(path: planetID)
            .appending(path: "avatar.png")
        let localAvatarURL = planetPath.appending(path: "avatar.png")
        let (data, _) = try await URLSession.shared.data(from: remoteAvatarURL)
        var shouldReloadAvatar: Bool = false
        if FileManager.default.fileExists(atPath: localAvatarURL.path) {
            let remoteAvatarDataCount = UIImage(data: data)?.pngData()?.count ?? 0
            let localAvatarDataCount = UIImage(contentsOfFile: localAvatarURL.path)?.pngData()?.count ?? 0
            if remoteAvatarDataCount != localAvatarDataCount && remoteAvatarDataCount > 0 {
                try? FileManager.default.removeItem(at: localAvatarURL)
                try data.write(to: localAvatarURL)
                shouldReloadAvatar = true
            }
        } else {
            try data.write(to: localAvatarURL)
            shouldReloadAvatar = true
        }
        guard shouldReloadAvatar else { return }
        try? await Task.sleep(nanoseconds: 150_000_000)
        await MainActor.run {
            NotificationCenter.default.post(name: .reloadAvatar(byID: planetID), object: nil)
        }
    }

    func validatePayloadSize(_ attachments: [PlanetArticleAttachment], maxSizeMB: Int64 = 25) -> (Bool, String?) {
        let maxSize: Int64 = maxSizeMB * 1024 * 1024 // Convert MB to bytes
        var totalSize: Int64 = 0
        for attachment in attachments {
            guard let fileSize = try? FileManager.default.attributesOfItem(atPath: attachment.url.path)[.size] as? Int64 else {
                continue
            }
            totalSize += fileSize
        }
        if totalSize > maxSize {
            let totalSizeMB = Double(totalSize) / (1024 * 1024)
            debugPrint("📤 [Upload] Total attachments size (\(String(format: "%.1f", totalSizeMB))MB) exceeds maximum allowed size (\(maxSizeMB)MB)")
            return (false, "Total attachments size (\(String(format: "%.1f", totalSizeMB))MB) exceeds maximum allowed size (\(maxSizeMB)MB)")
        }
        return (true, nil)
    }

    // MARK: - ⚙️ API Functions
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
                try data.write(to: planetPath.appending(path: "planet.json"))
                Task(priority: .background) {
                    do {
                        try await self.downloadPlanetAvatar(planetID: planet.id)
                    } catch {
                        debugPrint("failed to download avatar for planet: \(planet.id), error: \(error)")
                    }
                }
            }
        }
        return planets
    }

    // MARK: - create planet
    func createPlanet(name: String, about: String, templateName: String, avatarPath: String) async throws {
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
                MultipartForm.Part(name: "template", value: templateName),
                MultipartForm.Part(name: "avatar", data: data, filename: imageName, contentType: contentType)
            ])
        } else {
            form = MultipartForm(parts: [
                MultipartForm.Part(name: "name", value: name),
                MultipartForm.Part(name: "about", value: about),
                MultipartForm.Part(name: "template", value: templateName)
            ])
        }
        request.setValue(form.contentType, forHTTPHeaderField: "Content-Type")
        let _ = try await URLSession.shared.upload(for: request, from: form.bodyData)
        await MainActor.run {
            NotificationCenter.default.post(name: .updatePlanets, object: nil)
            if let planet = PlanetAppViewModel.shared.myPlanets.first {
                NotificationCenter.default.post(name: .reloadAvatar(byID: planet.id), object: nil)
            }
        }
    }

    // MARK: - modify planet
    func modifyPlanet(id: String, name: String, about: String, templateName: String, avatarPath: String) async throws {
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
                MultipartForm.Part(name: "template", value: templateName),
                MultipartForm.Part(name: "avatar", data: data, filename: imageName, contentType: contentType)
            ])
        } else {
            form = MultipartForm(parts: [
                MultipartForm.Part(name: "name", value: name),
                MultipartForm.Part(name: "about", value: about),
                MultipartForm.Part(name: "template", value: templateName)
            ])
        }
        request.setValue(form.contentType, forHTTPHeaderField: "Content-Type")
        let _ = try await URLSession.shared.upload(for: request, from: form.bodyData)
        var shouldReloadAvatar: Bool = false
        if avatarPath != "", let planetPath = getPlanetPath(forID: id) {
            shouldReloadAvatar = true
            let planetAvatarPath = planetPath.appending(path: "avatar.png")
            if FileManager.default.fileExists(atPath: planetAvatarPath.path) {
                try? FileManager.default.removeItem(at: planetAvatarPath)
                try? FileManager.default.copyItem(at: URL(fileURLWithPath: avatarPath), to: planetAvatarPath)
            }
        }
        await MainActor.run {
            NotificationCenter.default.post(name: .updatePlanets, object: nil)
        }
        guard shouldReloadAvatar else { return }
        await MainActor.run {
            NotificationCenter.default.post(name: .reloadAvatar(byID: id), object: nil)
        }
    }

    // MARK: - delete planet
    func deletePlanet(id: String) async throws {
        let request = try await createRequest(with: "/v0/planets/my/\(id)", method: "DELETE")
        let _ = try await URLSession.shared.data(for: request)
        // remove donation for share extension
        Task.detached(priority: .utility) {
            do {
                try await PlanetShareManager.shared.removeDonatedPlanet(planetID: id)
            } catch {
                debugPrint("failed to remove donated planet: \(id), error: \(error)")
            }
        }
        await MainActor.run {
            NotificationCenter.default.post(name: .updatePlanets, object: nil)
        }
        guard let nodeID = PlanetAppViewModel.shared.currentNodeID else { return }
        let planetPath = documentDirectory
            .appending(path: nodeID)
            .appending(path: "My")
            .appending(path: id)
        try? FileManager.default.removeItem(at: planetPath)
    }

    // MARK: - list my articles
    func getMyArticles() async throws -> [PlanetArticle] {
        var planets = PlanetAppViewModel.shared.myPlanets
        if planets.count == 0 {
            planets = try await getMyPlanets()
        }
        let planetIDs: [String] = planets.map { p in
            return p.id
        }
        guard planetIDs.count > 0 else { return [] }
        return try await withThrowingTaskGroup(of: [PlanetArticle].self) { group in
            var articles: [PlanetArticle] = []
            // fetch articles from different planets inside task group.
            for planetID in planetIDs {
                group.addTask {
                    let request = try await self.createRequest(with: "/v0/planets/my/\(planetID)/articles", method: "GET")
                    let (data, _) = try await URLSession.shared.data(for: request)
                    let decoder = JSONDecoder()
                    // skip situations that articles not found
                    guard let planetArticles: [PlanetArticle] = try? decoder.decode([PlanetArticle].self, from: data) else {
                        return []
                    }
                    let result = planetArticles.map { p in
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
                        try? FileManager.default.removeItem(at: articlesPath)
                        try data.write(to: articlesPath)
                    }
                    return result
                }
            }
            for try await items in group {
                articles.append(contentsOf: items)
            }
            return articles
        }
    }

    // MARK: - create article
    func createArticle(title: String, content: String, attachments: [PlanetArticleAttachment], forPlanet planet: Planet, isFromDraft: Bool = false, isFromShareExtension: Bool = false) async throws {
        do {
            if isFromShareExtension {
                var request = try await createRequest(with: "/v0/planets/my/\(planet.id)/articles", method: "POST")
                var form: MultipartForm = MultipartForm(parts: [
                    MultipartForm.Part(name: "title", value: title),
                    MultipartForm.Part(name: "date", value: Date().ISO8601Format()),
                    MultipartForm.Part(name: "content", value: content)
                ])
                for i in 0..<attachments.count {
                    let attachment = attachments[i]
                    let attachmentName = attachment.url.lastPathComponent
                    let attachmentContentType = attachment.url.mimeType()
                    let attachmentData = try Data(contentsOf: attachment.url)
                    let data = MultipartForm.Part(name: "attachments[\(i)]", data: attachmentData, filename: attachmentName, contentType: attachmentContentType)
                    form.parts.append(data)
                }
                request.setValue(form.contentType, forHTTPHeaderField: "Content-Type")
                let _ = try await URLSession.shared.upload(for: request, from: form.bodyData)
                // donate article for share extension
                Task.detached(priority: .utility) {
                    do {
                        try await PlanetShareManager.shared.donatePost(forPlanet: planet, content: title + " " + content)
                    } catch {
                        debugPrint("failed to donate post: \(title), error: \(error)")
                    }
                }
                await MainActor.run {
                    NotificationCenter.default.post(name: .reloadArticles, object: nil)
                }
            } else {
                try await PlanetArticleUploader.shared.createArticle(
                    title: title,
                    content: content,
                    attachments: attachments,
                    forPlanet: planet
                )
            }
        } catch {
            if !isFromDraft {
                let draftID = UUID()
                _ = try PlanetManager.shared.renderArticlePreview(forTitle: title, content: content, andArticleID: draftID.uuidString)
                let draftAttachments = attachments.map { a in
                    return a.url.lastPathComponent
                }
                try? saveArticleDraft(byID: draftID, attachments: draftAttachments, title: title, content: content, planetID: UUID(uuidString: planet.id))
            }
            throw error
        }
    }

    // MARK: - modify article
    func modifyArticle(id: String, title: String, content: String, attachments: [PlanetArticleAttachment], planetID: String) async throws {
        try await PlanetArticleUploader.shared.modifyArticle(
            id: id,
            title: title,
            content: content,
            attachments: attachments,
            planetID: planetID
        )
    }

    // MARK: - delete article
    func deleteArticle(id: String, planetID: String) async throws {
        // DELETE /v0/planets/my/:planet_uuid/articles/:article_uuid
        let deleteRequest = try await createRequest(with: "/v0/planets/my/\(planetID)/articles/\(id)", method: "DELETE")
        let _ = try await URLSession.shared.data(for: deleteRequest)
        if let articlePath = getPlanetArticlePath(forID: planetID, articleID: id) {
            try? FileManager.default.removeItem(at: articlePath)
        }
        // Update articles.json
        // /Documents/:node_id/My/:planet_id/articles.json
        let listRequest = try await self.createRequest(with: "/v0/planets/my/\(planetID)/articles", method: "GET")
        let (data, _) = try await URLSession.shared.data(for: listRequest)
        let updatedArticles: [PlanetArticle] = {
            let decoder = JSONDecoder()
            guard let articles: [PlanetArticle] = try? decoder.decode([PlanetArticle].self, from: data) else {
                return []
            }
            return articles.map { p in
                var t = p
                t.planetID = UUID(uuidString: planetID)
                return t
            }
        }()
        if let articlesPath = self.getPlanetArticlesPath(forID: planetID) {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(updatedArticles)
            try? FileManager.default.removeItem(at: articlesPath)
            try data.write(to: articlesPath)
        }
        await MainActor.run {
            NotificationCenter.default.post(name: .reloadArticles, object: nil)
            NotificationCenter.default.post(name: .updatePlanets, object: nil)
        }
    }

    // MARK: - ⚙️ Helper Functions
    func basicAuthenticationValue(username: String, password: String) throws -> String {
        let loginString = "\(username):\(password)"
        guard let loginData = loginString.data(using: .utf8) else {
            throw PlanetError.APIServerAuthenticationInvalidError
        }
        let base64LoginString = loginData.base64EncodedString()
        return "Basic \(base64LoginString)"
    }

    func getPlanetPath(forID planetID: String) -> URL? {
        guard let nodeID = PlanetAppViewModel.shared.currentNodeID else {
            return nil
        }
        let myPlanetPath = documentDirectory
            .appending(path: nodeID)
            .appending(path: "My")
            .appending(path: planetID)
        if !FileManager.default.fileExists(atPath: myPlanetPath.path) {
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
        let myPlanetArticlesPath = planetPath?.appending(path: "articles.json")
        return myPlanetArticlesPath
    }

    func getPlanetArticlePath(forID planetID: String, articleID: String) -> URL? {
        guard let _ = PlanetAppViewModel.shared.currentNodeID else {
            return nil
        }
        guard let planetPath = getPlanetPath(forID: planetID) else {
            return nil
        }
        let articlePath = planetPath.appending(path: articleID)
        if !FileManager.default.fileExists(atPath: articlePath.path) {
            try? FileManager.default.createDirectory(at: articlePath, withIntermediateDirectories: true)
        }
        return articlePath
    }

    func getPlanetArticleURL(forID planetID: String, articleID: String) -> URL? {
        guard let articlePath = getPlanetArticlePath(forID: planetID, articleID: articleID) else { return nil }
        let indexURL = articlePath.appending(path: "index.html")
        let simpleURL = articlePath.appending(path: "simple.html")
        let infoURL = articlePath.appending(path: "article.json")
        if FileManager.default.fileExists(atPath: indexURL.path) && FileManager.default.fileExists(atPath: infoURL.path) {
            if FileManager.default.fileExists(atPath: simpleURL.path) {
                return simpleURL
            }
            return indexURL
        }
        return nil
    }

    func renderArticlePreview(forTitle title: String, content: String, andArticleID articleID: String) throws -> URL {
        let tmp = URL.cachesDirectory
        let articlePath = tmp.appending(path: articleID).appendingPathExtension("html")
        try? FileManager.default.removeItem(at: articlePath)
        let titleAndContent = "# " + title + "\n" + content
        let html = CMarkRenderer.renderMarkdownHTML(markdown: titleAndContent)
        let output = try previewRenderEnv.renderTemplate(
            name: previewTemplatePath.path,
            context: ["content_html": html as Any]
        )
        try output.data(using: .utf8)?.write(to: articlePath)
        return articlePath
    }

    func renderEditArticlePreview(forTitle title: String, content: String, articleID: String, andAttachmentsPath attachmentsPath: URL) throws -> URL {
        guard FileManager.default.fileExists(atPath: attachmentsPath.path) else {
            throw PlanetError.InternalError
        }
        let articlePath = attachmentsPath.appending(path: articleID).appendingPathExtension("html")
        try? FileManager.default.removeItem(at: articlePath)
        let titleAndContent = "# " + title + "\n" + content
        let html = CMarkRenderer.renderMarkdownHTML(markdown: titleAndContent)
        let output = try previewRenderEnv.renderTemplate(
            name: previewTemplatePath.path,
            context: ["content_html": html as Any]
        )
        try output.data(using: .utf8)?.write(to: articlePath)
        return articlePath
    }

    func loadArticleDrafts() throws -> [PlanetArticle] {
        let paths: [String] = try FileManager.default.contentsOfDirectory(atPath: draftsDirectory.path)
        var drafts: [PlanetArticle] = []
        for path in paths {
            guard let id = UUID(uuidString: path) else { continue }
            if let article = try? loadArticleDraft(byID: id) {
                drafts.append(article)
            }
        }
        return drafts
    }

    func loadArticleDraft(byID id: UUID) throws -> PlanetArticle {
        let articlePath = draftsDirectory.appending(path: id.uuidString)
        guard FileManager.default.fileExists(atPath: articlePath.path) else {
            throw PlanetError.PlanetDraftNotExistsError
        }
        let articleInfoPath = articlePath.appending(path: "draft.json")
        let decoder = JSONDecoder()
        let data = try Data(contentsOf: articleInfoPath)
        let article = try decoder.decode(PlanetArticle.self, from: data)
        debugPrint("loaded article draft: \(article), at: \(articlePath)")
        return article
    }

    func saveArticleDraft(byID id: UUID, attachments: [String] = [], title: String?, content: String?, planetID: UUID?) throws {
        debugPrint("saving article draft by id: \(id) ...")
        /*
            Save as draft
            - A draft's directory: [Documents]/Drafts/[Article UUID]/
            - Inside:
                - draft.json [Codable object of PlanetArticle]
                - draft.html
                - attachments
         */
        let tempDirectory = URL.cachesDirectory
        let tempArticlePath = tempDirectory.appending(path: "\(id.uuidString).html")
        guard FileManager.default.fileExists(atPath: tempArticlePath.path) else {
            throw PlanetError.PlanetDraftError
        }
        let articleDraftPath = draftsDirectory.appending(path: id.uuidString)
        if FileManager.default.fileExists(atPath: articleDraftPath.path) {
            try FileManager.default.removeItem(at: articleDraftPath)
        }
        try FileManager.default.createDirectory(at: articleDraftPath, withIntermediateDirectories: true)
        let articlePath = articleDraftPath.appending(path: "draft.html")
        try FileManager.default.moveItem(at: tempArticlePath, to: articlePath)
        for attachment in attachments {
            let tempAttachmentPath = tempDirectory.appending(path: attachment)
            let attachmentPath = articleDraftPath.appending(path: attachment)
            try? FileManager.default.moveItem(at: tempAttachmentPath, to: attachmentPath)
        }
        let article = PlanetArticle(id: id.uuidString, created: Date(), title: title, content: content, summary: nil, link: id.uuidString, attachments: attachments, planetID: planetID)
        let encoder = JSONEncoder()
        let articleInfoPath = articleDraftPath.appending(path: "draft.json")
        let data = try encoder.encode(article)
        try data.write(to: articleInfoPath)
        debugPrint("saved article draft at: \(articleDraftPath)")
        Task(priority: .background) {
            do {
                let drafts = try self.loadArticleDrafts()
                Task { @MainActor in
                    PlanetAppViewModel.shared.updateDrafts(drafts)
                }
            } catch {
                debugPrint("failed to load drafts: \(error)")
            }
        }
    }

    func removeArticleDraft(_ draft: PlanetArticle) {
        let articleDraftPath = draftsDirectory.appending(path: draft.id)
        try? FileManager.default.removeItem(at: articleDraftPath)
        debugPrint("removed article draft: \(articleDraftPath)")
    }

    // MARK: - load planets and articles from disk
    func loadPlanetsAndArticlesFromNode(byID id: String) throws -> (planets: [Planet], articles: [PlanetArticle]) {
        let nodeURL = documentDirectory.appending(path: id)
        guard FileManager.default.fileExists(atPath: nodeURL.path) else { throw PlanetError.APINodeNotExistsError }
        let baseURL = nodeURL.appending(path: "My")
        let planetIDs: [String] = try FileManager.default.contentsOfDirectory(atPath: baseURL.path)
        let decoder = JSONDecoder()
        var planets: [Planet] = []
        var articles: [PlanetArticle] = []
        for planetID in planetIDs {
            let planetInfoPath = baseURL.appending(path: planetID).appending(path: "planet.json")
            if !FileManager.default.fileExists(atPath: planetInfoPath.path) {
                continue
            }
            let planetData = try Data(contentsOf: planetInfoPath)
            let planet = try decoder.decode(Planet.self, from: planetData)
            planets.append(planet)
            let articleInfoPath = baseURL.appending(path: planetID).appending(path: "articles.json")
            if !FileManager.default.fileExists(atPath: articleInfoPath.path) {
                continue
            }
            let articlesData = try Data(contentsOf: articleInfoPath)
            let planetArticles = try decoder.decode([PlanetArticle].self, from: articlesData)
            articles.append(contentsOf: planetArticles)
        }
        return (planets, articles)
    }

    // MARK: - reset local cache
    func resetLocalCache() async throws {
        guard let nodeID = PlanetAppViewModel.shared.currentNodeID else { return }
        let nodePath = documentDirectory.appending(path: nodeID)
        try? FileManager.default.removeItem(at: nodePath)
    }
}
