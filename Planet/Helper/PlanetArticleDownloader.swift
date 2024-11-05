//
//  PlanetArticleDownloader.swift
//  Planet
//


import SwiftUI
import Foundation

// MARK: - Background Downloader
private class PlanetBackgroundArticleDownloader: NSObject {
    static let shared = PlanetBackgroundArticleDownloader()

    static let sessionIdentifier: String = "com.planet.attachmentdownloader"
    static let delegateQueue: String = "com.planet.attachmentdownloader.queue"

    private var backgroundUrlSession: URLSession!
    private var downloadTasks: [URL: URLSessionDownloadTask] = [:]
    private var completionHandlers: [URL: (Result<URL, Error>) -> Void] = [:]
    private var destinationPaths: [URL: URL] = [:]

    override init() {
        super.init()

        let config = URLSessionConfiguration.background(withIdentifier: Self.sessionIdentifier)
        config.isDiscretionary = true
        config.sessionSendsLaunchEvents = true

        let delegateQueue = OperationQueue()
        delegateQueue.name = Self.delegateQueue
        delegateQueue.maxConcurrentOperationCount = 2
        backgroundUrlSession = URLSession(configuration: config, delegate: self, delegateQueue: delegateQueue)

        // Resume pending downloads
        backgroundUrlSession.getAllTasks { tasks in
            tasks.forEach { task in
                if let originalURL = task.originalRequest?.url {
                    debugPrint("📥 Found pending task: \(task.taskIdentifier) - \(originalURL.lastPathComponent)")
                    self.downloadTasks[originalURL] = task as? URLSessionDownloadTask
                    if self.completionHandlers[originalURL] == nil {
                        debugPrint("⚠️ No handler found, cancelling task: \(task.taskIdentifier)")
                        task.cancel()
                        self.downloadTasks.removeValue(forKey: originalURL)
                    }
                } else {
                    debugPrint("⚠️ Invalid task, cancelling: \(task.taskIdentifier)")
                    task.cancel()
                }
            }
        }
    }

    func download(url: URL, destinationPath: URL, completion: @escaping (Result<URL, Error>) -> Void) {
        if let existingTask = self.downloadTasks[url] {
            debugPrint("📥 Reusing task: \(existingTask.taskIdentifier) - \(url.lastPathComponent)")
            if self.completionHandlers[url] != nil {
                completion(.failure(PlanetError.ArticleDownloadingTaskExistsError))
                return
            }
            self.completionHandlers[url] = completion
            self.destinationPaths[url] = destinationPath
        } else {
            let task = self.backgroundUrlSession.downloadTask(with: url)
            debugPrint("📥 Starting task: \(task.taskIdentifier) - \(url.lastPathComponent)")
            self.downloadTasks[url] = task
            self.completionHandlers[url] = completion
            self.destinationPaths[url] = destinationPath
            task.resume()
        }
    }

    private func cleanupTask(for url: URL) {
        self.downloadTasks.removeValue(forKey: url)
        self.completionHandlers.removeValue(forKey: url)
        self.destinationPaths.removeValue(forKey: url)
    }
}

// MARK: - URLSessionDownloadDelegate
extension PlanetBackgroundArticleDownloader: URLSessionDownloadDelegate {
    func urlSession(_ session: URLSession,
                    downloadTask: URLSessionDownloadTask,
                    didFinishDownloadingTo location: URL) {
        guard let sourceURL = downloadTask.originalRequest?.url else {
            debugPrint("⚠️ Missing URL for task: \(downloadTask.taskIdentifier)")
            return
        }

        // Always clean up task if handlers are missing
        guard let completion = completionHandlers[sourceURL],
              let destinationPath = destinationPaths[sourceURL] else {
            debugPrint("⚠️ Missing handlers for task: \(downloadTask.taskIdentifier)")
            cleanupTask(for: sourceURL)
            return
        }

        do {
            try FileManager.default.createDirectory(at: destinationPath.deletingLastPathComponent(),
                                                    withIntermediateDirectories: true)
            try? FileManager.default.removeItem(at: destinationPath)
            try FileManager.default.moveItem(at: location, to: destinationPath)

            DispatchQueue.main.async { completion(.success(destinationPath)) }
        } catch {
            debugPrint("❌ Failed task: \(downloadTask.taskIdentifier) - \(error.localizedDescription)")
            DispatchQueue.main.async { completion(.failure(error)) }
        }
        // Don't cleanup here - let didCompleteWithError handle it
    }

    func urlSession(_ session: URLSession,
                    task: URLSessionTask,
                    didCompleteWithError error: Error?) {
        guard let sourceURL = task.originalRequest?.url else { return }

        // Only call completion for error case
        if let error = error, let completion = completionHandlers[sourceURL] {
            debugPrint("❌ Failed task: \(task.taskIdentifier) - \(error.localizedDescription)")
            DispatchQueue.main.async { completion(.failure(error)) }
        }

        // Always clean up, even if handlers are missing
        cleanupTask(for: sourceURL)
    }

    func urlSession(_ session: URLSession,
                    downloadTask: URLSessionDownloadTask,
                    didWriteData bytesWritten: Int64,
                    totalBytesWritten: Int64,
                    totalBytesExpectedToWrite: Int64) {
        guard let sourceURL = downloadTask.originalRequest?.url else { return }
        let progress = Int(Float(totalBytesWritten) / Float(totalBytesExpectedToWrite) * 100)
        debugPrint("📥 Progress task: \(downloadTask.taskIdentifier) - \(sourceURL.lastPathComponent) (\(progress)%)")
    }

    func urlSession(_ session: URLSession,
                    downloadTask: URLSessionDownloadTask,
                    didResumeAtOffset fileOffset: Int64,
                    expectedTotalBytes: Int64) {
        guard let sourceURL = downloadTask.originalRequest?.url else { return }
        debugPrint("📥 Resumed task: \(downloadTask.taskIdentifier) - \(sourceURL.lastPathComponent)")
    }
}

// MARK: - Article Downloader
actor PlanetArticleDownloader {
    static let shared = PlanetArticleDownloader()

    private var isDownloading = false
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

    var isArticleDownloading: Bool {
        isDownloading
    }

    func download(byArticleID id: String, andPlanetID planetID: String, forceDownloadAttachments: Bool = false) async throws {
        if !forceDownloadAttachments {
            guard !isDownloading else {
                throw PlanetError.ArticleDownloadInProgressError
            }
        }
        isDownloading = true
        defer {
            isDownloading = false
        }

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
                        group.addTask {
                            let attachmentURL = articlePublicURL.appending(path: attachment)
                            let attachmentPath = articlePath.appending(path: attachment)

                            try await withCheckedThrowingContinuation { continuation in
                                PlanetBackgroundArticleDownloader.shared.download(
                                    url: attachmentURL,
                                    destinationPath: attachmentPath
                                ) { result in
                                    switch result {
                                        case .success(_):
                                            continuation.resume(returning: ())
                                        case .failure(let error):
                                            continuation.resume(throwing: error)
                                    }
                                }
                            }
                        }
                    }
                    try await group.waitForAll()
                }
            }
        }
        debugPrint("✅ Article download completed: \(id)")
    }
}
