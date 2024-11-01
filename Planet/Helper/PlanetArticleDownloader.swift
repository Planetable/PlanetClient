//
//  PlanetArticleDownloader.swift
//  Planet
//


import SwiftUI
import Foundation

// MARK: - Background Downloader
private class PlanetBackgroundArticleDownloader: NSObject {
    static let shared = PlanetBackgroundArticleDownloader()
    
    private var backgroundUrlSession: URLSession!
    private var downloadTasks: [URL: URLSessionDownloadTask] = [:]
    private var completionHandlers: [URL: (Result<URL, Error>) -> Void] = [:]
    private var destinationPaths: [URL: URL] = [:]
    
    override init() {
        super.init()
        
        let config = URLSessionConfiguration.background(withIdentifier: "com.planet.attachmentdownloader")
        config.isDiscretionary = true
        config.sessionSendsLaunchEvents = true
        
        let delegateQueue = OperationQueue()
        delegateQueue.name = "com.planet.attachmentdownloader.queue"
        delegateQueue.maxConcurrentOperationCount = 2
        backgroundUrlSession = URLSession(configuration: config, delegate: self, delegateQueue: delegateQueue)
        
        // Resume pending downloads
        backgroundUrlSession.getAllTasks { tasks in
            tasks.forEach { task in
                if let originalURL = task.originalRequest?.url {
                    debugPrint("📥 Found pending download for: \(originalURL.lastPathComponent)")
                    debugPrint("   Task identifier: \(task.taskIdentifier)")
                    DispatchQueue.main.async { [weak self] in
                        self?.downloadTasks[originalURL] = task as? URLSessionDownloadTask
                        // Cancel tasks that don't have handlers
                        if self?.completionHandlers[originalURL] == nil {
                            debugPrint("⚠️ No handler found for pending task, cancelling: \(originalURL.lastPathComponent)")
                            task.cancel()
                            self?.downloadTasks.removeValue(forKey: originalURL)
                        }
                    }
                } else {
                    debugPrint("⚠️ Found task without URL, cancelling: \(task.taskIdentifier)")
                    task.cancel()
                }
            }
        }
    }
    
    func download(url: URL, destinationPath: URL, completion: @escaping (Result<URL, Error>) -> Void) {
        debugPrint("🚀 Initiating background download for: \(url.lastPathComponent)")
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.destinationPaths[url] = destinationPath
            
            if let existingTask = self.downloadTasks[url] {
                debugPrint("✳️ Existing download found for: \(url.lastPathComponent)")
                debugPrint("   Task identifier: \(existingTask.taskIdentifier)")
                self.completionHandlers[url] = completion
            } else {
                let task = self.backgroundUrlSession.downloadTask(with: url)
                debugPrint("🆕 Creating new download task: \(task.taskIdentifier) for: \(url.lastPathComponent)")
                self.downloadTasks[url] = task
                self.completionHandlers[url] = completion
                task.resume()
            }
        }
    }
    
    private func cleanupTask(for url: URL) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            debugPrint("🧹 Cleaning up task for: \(url.lastPathComponent)")
            self.downloadTasks.removeValue(forKey: url)
            self.completionHandlers.removeValue(forKey: url)
            self.destinationPaths.removeValue(forKey: url)
        }
    }
}

// MARK: - URLSessionDownloadDelegate
extension PlanetBackgroundArticleDownloader: URLSessionDownloadDelegate {
    func urlSession(_ session: URLSession,
                   downloadTask: URLSessionDownloadTask,
                   didFinishDownloadingTo location: URL) {
        guard let sourceURL = downloadTask.originalRequest?.url else {
            debugPrint("🔴 Background download - Missing URL for task: \(downloadTask.taskIdentifier)")
            return
        }
        
        guard let completion = completionHandlers[sourceURL] else {
            debugPrint("🔴 Background download - Missing completion handler for: \(sourceURL.lastPathComponent)")
            debugPrint("   Task identifier: \(downloadTask.taskIdentifier)")
            return
        }
        
        guard let destinationPath = destinationPaths[sourceURL] else {
            debugPrint("🔴 Background download - Missing destination path for: \(sourceURL.lastPathComponent)")
            completion(.failure(NSError(domain: "PlanetDownloader", code: -1, userInfo: [NSLocalizedDescriptionKey: "Missing destination path"])))
            cleanupTask(for: sourceURL)
            return
        }
        
        debugPrint("✅ Background download completed for: \(sourceURL.lastPathComponent)")
        debugPrint("   Task identifier: \(downloadTask.taskIdentifier)")
        
        do {
            try FileManager.default.createDirectory(at: destinationPath.deletingLastPathComponent(), 
                                                 withIntermediateDirectories: true)
            try? FileManager.default.removeItem(at: destinationPath)
            try FileManager.default.moveItem(at: location, to: destinationPath)
            
            DispatchQueue.main.async {
                completion(.success(destinationPath))
                self.cleanupTask(for: sourceURL)
            }
        } catch {
            debugPrint("❌ Failed to move file: \(error.localizedDescription)")
            DispatchQueue.main.async {
                completion(.failure(error))
                self.cleanupTask(for: sourceURL)
            }
        }
    }
    
    func urlSession(_ session: URLSession,
                   task: URLSessionTask,
                   didCompleteWithError error: Error?) {
        guard let sourceURL = task.originalRequest?.url,
              let completion = completionHandlers[sourceURL] else {
            debugPrint("🔴 Background download - Missing URL or completion handler for completed task: \(task)")
            return
        }
        
        if let error = error {
            debugPrint("❌ Background download failed for: \(sourceURL.lastPathComponent)")
            debugPrint("⚠️ Error: \(error.localizedDescription)")
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                completion(.failure(error))
                self.downloadTasks.removeValue(forKey: sourceURL)
                self.completionHandlers.removeValue(forKey: sourceURL)
                self.destinationPaths.removeValue(forKey: sourceURL)
                debugPrint("🧹 Cleaned up handlers for failed download: \(sourceURL.lastPathComponent)")
            }
        }
    }
    
    func urlSession(_ session: URLSession,
                   downloadTask: URLSessionDownloadTask,
                   didWriteData bytesWritten: Int64,
                   totalBytesWritten: Int64,
                   totalBytesExpectedToWrite: Int64) {
        guard let sourceURL = downloadTask.originalRequest?.url else { return }
        
        let progress = Float(totalBytesWritten) / Float(totalBytesExpectedToWrite)
        debugPrint("📥 Download progress for \(sourceURL.lastPathComponent): \(Int(progress * 100))%")
        debugPrint("   Bytes written: \(ByteCountFormatter.string(fromByteCount: totalBytesWritten, countStyle: .file))")
    }
    
    func urlSession(_ session: URLSession,
                   downloadTask: URLSessionDownloadTask,
                   didResumeAtOffset fileOffset: Int64,
                   expectedTotalBytes: Int64) {
        guard let sourceURL = downloadTask.originalRequest?.url else { return }
        debugPrint("⏯️ Resumed download for \(sourceURL.lastPathComponent) at offset: \(ByteCountFormatter.string(fromByteCount: fileOffset, countStyle: .file))")
    }
    
    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        debugPrint("🏁 Background URL session finished all events")
    }
}

// MARK: - Article Downloader
actor PlanetArticleDownloader {
    // MARK: - Main Actor Methods
    func download(byArticleID id: String, andPlanetID planetID: String, forceDownloadAttachments: Bool = false) async throws {
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
            debugPrint("downloading attachments (count = \(attachments.count)) ...")
            
            await withThrowingTaskGroup(of: Void.self) { group in
                for a in attachments {
                    let attachmentURL = articlePublicURL.appending(path: a)
                    let attachmentPath = articlePath.appending(path: a)
                    
                    group.addTask {
                        try await withCheckedThrowingContinuation { continuation in
                            PlanetBackgroundArticleDownloader.shared.download(
                                url: attachmentURL,
                                destinationPath: attachmentPath
                            ) { result in
                                switch result {
                                case .success(_):
                                    debugPrint("download attachment: \(attachmentURL)")
                                    continuation.resume()
                                case .failure(let error):
                                    continuation.resume(throwing: error)
                                }
                            }
                        }
                    }
                }
            }
            
            debugPrint("initiated all attachment downloads.")
        }
    }
}
