//
//  PlanetArticleDownloader.swift
//  Planet
//


import SwiftUI
import Foundation


actor PlanetArticleDownloader {
    func download(byArticleID id: String, andPlanetID planetID: String) async throws {
        let manager = PlanetManager.shared
        // GET /v0/planets/my/:planet_uuid/articles/:article_uuid
        let request = try await manager.createRequest(with: "/v0/planets/my/\(planetID)/articles/\(id)", method: "GET")
        let (data, response) = try await URLSession.shared.data(for: request)
        let statusCode = (response as! HTTPURLResponse).statusCode
        guard statusCode == 200 else { throw PlanetError.APIArticleNotFoundError }
        guard
            let articlePath = manager.getPlanetArticlePath(forID: planetID, articleID: id)
        else {
            throw PlanetError.APIArticleNotFoundError
        }
        guard
            let serverURL = URL(string: PlanetAppViewModel.shared.currentServerURLString)
        else {
            throw PlanetError.APIServerError
        }
        let articleInfoPath = articlePath.appending(path: "article.json")
        try data.write(to: articleInfoPath)
        let decoder = JSONDecoder()
        var planetArticle = try decoder.decode(PlanetArticle.self, from: data)
        planetArticle.planetID = UUID(uuidString: planetID)
        // download html and attachments, replace if exists.
        let articlePublicURL = serverURL
            .appending(path: planetID)
            .appending(path: id)
        // index.html, abort download task if not exists or failed.
        let articleURL = articlePublicURL.appending(path: "index.html")
        let articleIndexPath = articlePath.appending(path: "index.html")
        // simple.html if exists
        let simpleURL = articlePublicURL.appending(path: "simple.html")
        let simplePath = articlePath.appending(path: "simple.html")
        // blog.html if exists
        let blogURL = articlePublicURL.appending(path: "blog.html")
        let blogPath = articlePath.appending(path: "blog.html")
        await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask(priority: .background) {
                let (articleData, response) = try await URLSession.shared.data(from: articleURL)
                let statusCode = (response as! HTTPURLResponse).statusCode
                if statusCode == 200 {
                    try? FileManager.default.removeItem(at: articleIndexPath)
                    try articleData.write(to: articleIndexPath)
                }
            }
            group.addTask(priority: .background) {
                let (simpleData, response) = try await URLSession.shared.data(from: simpleURL)
                let statusCode = (response as! HTTPURLResponse).statusCode
                if statusCode == 200 {
                    try? FileManager.default.removeItem(at: simplePath)
                    try? simpleData.write(to: simplePath)
                }
            }
            group.addTask(priority: .background) {
                let (blogData, response) = try await URLSession.shared.data(from: blogURL)
                let statusCode = (response as! HTTPURLResponse).statusCode
                if statusCode == 200 {
                    try? FileManager.default.removeItem(at: blogPath)
                    try? blogData.write(to: blogPath)
                }
            }
        }
        // attachments
        if let attachments = planetArticle.attachments, attachments.count > 0 {
            await withThrowingTaskGroup(of: Void.self) { group in
                for a in attachments {
                    let attachmentURL = articlePublicURL.appending(path: a)
                    let attachmentPath = articlePath.appending(path: a)
                    group.addTask(priority: .background) {
                        let (attachmentData, response) = try await URLSession.shared.data(from: attachmentURL)
                        let statusCode = (response as! HTTPURLResponse).statusCode
                        if statusCode == 200 {
                            debugPrint("download attachment: \(attachmentURL)")
                            try? FileManager.default.removeItem(at: attachmentPath)
                            try? attachmentData.write(to: attachmentPath)
                        }
                    }
                }
            }
            debugPrint("downloaded all attachments.")
        }
        await MainActor.run {
            NotificationCenter.default.post(name: .reloadArticle(byID: id), object: nil)
        }
    }
}
