//
//  PlanetArticleDownloader.swift
//  Planet
//


import SwiftUI
import Foundation

// MARK: - Background Downloader
actor PlanetBackgroundArticleDownloader: NSObject {
    static let shared = PlanetBackgroundArticleDownloader()
    static let identifier: String = "com.planet.attachment.downloader"

    private var backgroundUrlSession: URLSession!
    private var downloadTasks: [URL: URLSessionDownloadTask] = [:]
    private var completionHandlers: [URL: (Result<URL, Error>) -> Void] = [:]
    private var destinationPaths: [URL: URL] = [:]
    
    override private init() {
        super.init()
        
        let config = URLSessionConfiguration.background(
            withIdentifier: Self.identifier
        )
        config.isDiscretionary = true
        config.sessionSendsLaunchEvents = true
        
        backgroundUrlSession = URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }
    
    func download(url: URL, destinationPath: URL) async throws -> URL {
        if downloadTasks[url] != nil {
            throw PlanetError.InternalError
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let task = backgroundUrlSession.downloadTask(with: url)
            downloadTasks[url] = task
            completionHandlers[url] = { result in
                continuation.resume(with: result)
            }
            destinationPaths[url] = destinationPath
            task.resume()
        }
    }
    
    private func cleanupTask(for url: URL) {
        downloadTasks.removeValue(forKey: url)
        completionHandlers.removeValue(forKey: url)
        destinationPaths.removeValue(forKey: url)
    }
}

extension PlanetBackgroundArticleDownloader: URLSessionDownloadDelegate {
    nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        guard let sourceURL = downloadTask.originalRequest?.url else { return }
        
        Task {
            await handleDownloadCompletion(sourceURL: sourceURL, location: location)
        }
    }
    
    private func handleDownloadCompletion(sourceURL: URL, location: URL) async {
        guard let completion = completionHandlers[sourceURL],
              let destinationPath = destinationPaths[sourceURL] else {
            cleanupTask(for: sourceURL)
            return
        }
        
        do {
            try FileManager.default.createDirectory(
                at: destinationPath.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try? FileManager.default.removeItem(at: destinationPath)
            try FileManager.default.moveItem(at: location, to: destinationPath)
            
            completion(.success(destinationPath))
        } catch {
            completion(.failure(error))
        }
        
        cleanupTask(for: sourceURL)
    }
    
    nonisolated func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        guard let sourceURL = task.originalRequest?.url else { return }
        
        if let error = error {
            Task {
                await handleError(error, for: sourceURL)
            }
        }
    }
    
    private func handleError(_ error: Error, for sourceURL: URL) async {
        guard let completion = completionHandlers[sourceURL] else { return }
        
        completion(.failure(error))
        cleanupTask(for: sourceURL)
    }
}

// MARK: - Article Downloader
actor PlanetArticleDownloader {
    private let cacheTimeout: TimeInterval = 1800 // 30 minutes (30 * 60 seconds)
    
    private func isFileRecent(_ url: URL) -> Bool {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let modificationDate = attributes[.modificationDate] as? Date else {
            return false
        }
        return Date().timeIntervalSince(modificationDate) < cacheTimeout
    }
    
    private func loadArticleFromDisk(at path: URL) -> PlanetArticle? {
        guard let data = try? Data(contentsOf: path) else { return nil }
        return try? JSONDecoder().decode(PlanetArticle.self, from: data)
    }
    
    func download(byArticleID id: String, andPlanetID planetID: String, forceDownloadAttachments: Bool = false) async throws {
        let manager = PlanetManager.shared
        guard let articlePath = manager.getPlanetArticlePath(forID: planetID, articleID: id) else {
            throw PlanetError.APIArticleNotFoundError
        }
        
        let articleJsonPath = articlePath.appending(path: "article.json")
        var planetArticle: PlanetArticle
        var needsDownload = forceDownloadAttachments
        
        // First check if we can use cached article.json
        if !forceDownloadAttachments,
           FileManager.default.fileExists(atPath: articleJsonPath.path),
           isFileRecent(articleJsonPath),
           let cachedArticle = loadArticleFromDisk(at: articleJsonPath) {
            debugPrint("📄 Using cached article.json for: \(id)")
            planetArticle = cachedArticle
        } else {
            // Fetch fresh article.json from server
            debugPrint("🌐 Fetching article.json from server for: \(id)")
            let request = try await manager.createRequest(with: "/v0/planets/my/\(planetID)/articles/\(id)", method: "GET")
            let (data, response) = try await URLSession.shared.data(for: request)
            let statusCode = (response as! HTTPURLResponse).statusCode
            guard statusCode == 200 else { throw PlanetError.APIArticleNotFoundError }
            
            let decoder = JSONDecoder()
            planetArticle = try decoder.decode(PlanetArticle.self, from: data)
            planetArticle.planetID = UUID(uuidString: planetID)
            
            // Save new article.json
            try data.write(to: articleJsonPath)
            debugPrint("💾 Saved new article.json for: \(id)")
            needsDownload = true
        }
        
        // Setup URLs for all downloads
        guard let serverURL = URL(string: PlanetAppViewModel.shared.currentServerURLString) else {
            throw PlanetError.APIServerError
        }
        let articlePublicURL = serverURL.appending(path: planetID).appending(path: id)
        
        let indexPath = articlePath.appending(path: "index.html")
        if needsDownload || !FileManager.default.fileExists(atPath: indexPath.path) || !isFileRecent(indexPath) {
            // Download all HTML files concurrently
            await withThrowingTaskGroup(of: Void.self) { group in
                // index.html (required)
                group.addTask {
                    debugPrint("📥 Downloading index.html for: \(id)")
                    let articleURL = articlePublicURL.appending(path: "index.html")
                    let indexPath = articlePath.appending(path: "index.html")
                    
                    let (articleData, response) = try await URLSession.shared.data(from: articleURL)
                    if (response as! HTTPURLResponse).statusCode == 200 {
                        try? FileManager.default.removeItem(at: indexPath)
                        try articleData.write(to: indexPath)
                        debugPrint("✅ Downloaded index.html")
                    } else {
                        throw PlanetError.APIArticleNotFoundError
                    }
                }
                
                // simple.html (optional)
                group.addTask(priority: .background) {
                    let simpleURL = articlePublicURL.appending(path: "simple.html")
                    let simplePath = articlePath.appending(path: "simple.html")
                    do {
                        let (simpleData, response) = try await URLSession.shared.data(from: simpleURL)
                        if (response as! HTTPURLResponse).statusCode == 200 {
                            try? FileManager.default.removeItem(at: simplePath)
                            try simpleData.write(to: simplePath)
                            debugPrint("✅ Downloaded simple.html")
                        }
                    } catch {
                        debugPrint("ℹ️ simple.html not available")
                    }
                }
                
                // blog.html (optional)
                group.addTask(priority: .background) {
                    let blogURL = articlePublicURL.appending(path: "blog.html")
                    let blogPath = articlePath.appending(path: "blog.html")
                    do {
                        let (blogData, response) = try await URLSession.shared.data(from: blogURL)
                        if (response as! HTTPURLResponse).statusCode == 200 {
                            try? FileManager.default.removeItem(at: blogPath)
                            try blogData.write(to: blogPath)
                            debugPrint(" Downloaded blog.html")
                        }
                    } catch {
                        debugPrint("ℹ️ blog.html not available")
                    }
                }
            }
        }
        
        // Check attachments
        if let attachments = planetArticle.attachments, attachments.count > 0 {
            let existingAttachments = (try? FileManager.default.contentsOfDirectory(
                at: articlePath,
                includingPropertiesForKeys: nil
            )) ?? []
            
            let existingAttachmentNames = Set(existingAttachments.map { $0.lastPathComponent }
                .filter { name in
                    !name.hasSuffix(".json") && 
                    !name.hasSuffix(".html")
                })
            let requiredAttachments = Set(attachments)
            
            if forceDownloadAttachments || !requiredAttachments.isSubset(of: existingAttachmentNames) {
                debugPrint("📥 Downloading attachments (count = \(attachments.count))")
                
                try await withThrowingTaskGroup(of: Void.self) { group in
                    for attachment in attachments {
                        group.addTask { [articlePublicURL, articlePath] in  // Capture values explicitly
                            let attachmentURL = articlePublicURL.appending(path: attachment)
                            let attachmentPath = articlePath.appending(path: attachment)
                            
                            let _ = try await PlanetBackgroundArticleDownloader.shared.download(
                                url: attachmentURL,
                                destinationPath: attachmentPath
                            )
                        }
                    }
                    
                    try await group.waitForAll()
                }
                
                debugPrint("✅ Article download completed: \(id)")
            }
        }
    }
}
