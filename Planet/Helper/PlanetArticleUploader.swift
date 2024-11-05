//
//  PlanetArticleUploader.swift
//  Planet
//

import Foundation

// MARK: - Background Uploader
private class PlanetBackgroundArticleUploader: NSObject, URLSessionDataDelegate {
    static let shared = PlanetBackgroundArticleUploader()
    
    static let sessionIdentifier: String = "com.planet.articleuploader"
    static let delegateQueue: String = "com.planet.articleuploader.queue"
    
    private var backgroundUrlSession: URLSession!
    private var uploadTasks: [String: URLSessionUploadTask] = [:]  // articleID: task
    private var completionHandlers: [String: (Result<Void, Error>) -> Void] = [:]
    private var tempFiles: [String: URL] = [:] // articleID: tempFileURL
    private var statusCodes: [Int: Int] = [:] // taskIdentifier: statusCode
    private var responseData: [Int: Data] = [:] // taskIdentifier: response data
    
    override init() {
        super.init()
        debugPrint("📤 [Upload] PlanetBackgroundArticleUploader initialized")
        
        let config = URLSessionConfiguration.background(withIdentifier: Self.sessionIdentifier)
        config.isDiscretionary = true
        config.sessionSendsLaunchEvents = true
        
        let delegateQueue = OperationQueue()
        delegateQueue.name = Self.delegateQueue
        delegateQueue.maxConcurrentOperationCount = 1
        backgroundUrlSession = URLSession(configuration: config, delegate: self, delegateQueue: delegateQueue)
        
        // Resume pending uploads
        backgroundUrlSession.getAllTasks { tasks in
            tasks.forEach { task in
                if let originalRequest = task.originalRequest,
                   let articleID = self.extractArticleID(from: originalRequest.url?.path ?? "") {
                    debugPrint("📤 [Upload] Found pending task: \(task.taskIdentifier) - Article: \(articleID)")
                    self.uploadTasks[articleID] = task as? URLSessionUploadTask
                    if self.completionHandlers[articleID] == nil {
                        debugPrint("📤 [Upload] ⚠️ No handler found, cancelling task: \(task.taskIdentifier)")
                        task.cancel()
                        self.uploadTasks.removeValue(forKey: articleID)
                    }
                } else {
                    debugPrint("📤 [Upload] ⚠️ Invalid task, cancelling: \(task.taskIdentifier)")
                    task.cancel()
                }
            }
        }
    }
    
    private func extractArticleID(from path: String) -> String? {
        let components = path.split(separator: "/")
        guard components.count >= 2 else { return nil }
        return String(components[components.count - 1])
    }
    
    func upload(request: URLRequest, form: MultipartForm, articleID: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let tempFileURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        do {
            try form.bodyData.write(to: tempFileURL)
        } catch {
            completion(.failure(error))
            return
        }
        
        var modifiedRequest = request
        modifiedRequest.setValue(form.contentType, forHTTPHeaderField: "Content-Type")
        
        if let existingTask = self.uploadTasks[articleID] {
            debugPrint("📤 [Upload] Reusing task: \(existingTask.taskIdentifier) - Article: \(articleID)")
            if self.completionHandlers[articleID] != nil {
                completion(.failure(PlanetError.ArticleUploadingTaskExistsError))
                return
            }
        } else {
            let task = self.backgroundUrlSession.uploadTask(with: modifiedRequest, fromFile: tempFileURL)
            debugPrint("📤 [Upload] Starting task: \(task.taskIdentifier) - Article: \(articleID)")
            self.uploadTasks[articleID] = task
            self.tempFiles[articleID] = tempFileURL
            task.resume()
        }
        
        self.completionHandlers[articleID] = completion
    }
    
    private func cleanupTask(for articleID: String) {
        if let tempFile = tempFiles[articleID] {
            try? FileManager.default.removeItem(at: tempFile)
        }
        uploadTasks.removeValue(forKey: articleID)
        completionHandlers.removeValue(forKey: articleID)
        tempFiles.removeValue(forKey: articleID)
    }
    
    func urlSession(_ session: URLSession,
                    task: URLSessionTask,
                    didSendBodyData bytesSent: Int64,
                    totalBytesSent: Int64,
                    totalBytesExpectedToSend: Int64) {
        guard let articleID = extractArticleID(from: task.originalRequest?.url?.path ?? "") else { return }
        let progress = Int(Float(totalBytesSent) / Float(totalBytesExpectedToSend) * 100)
        if progress >= 100 {
            debugPrint("📤 [Upload] Upload completed, waiting for server processing - Article: \(articleID)")
        } else {
            debugPrint("📤 [Upload] Progress task: \(task.taskIdentifier) - Article: \(articleID) (\(progress)%)")
        }
    }
    
    func urlSession(_ session: URLSession,
                    dataTask: URLSessionDataTask,
                    didReceive response: URLResponse,
                    completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        debugPrint("📤 [Upload] Server started responding")
        if let httpResponse = response as? HTTPURLResponse {
            debugPrint("📤 [Upload] HTTP status code: \(httpResponse.statusCode)")
            statusCodes[dataTask.taskIdentifier] = httpResponse.statusCode
        }
        completionHandler(.allow)
    }
    
    func urlSession(_ session: URLSession,
                    dataTask: URLSessionDataTask,
                    didReceive data: Data) {
        debugPrint("📤 [Upload] Received server response")
        // Store response data
        responseData[dataTask.taskIdentifier] = data
        if let responseString = String(data: data, encoding: .utf8) {
            debugPrint("📤 [Upload] Response data: \(responseString)")
        }
    }
    
    func urlSession(_ session: URLSession,
                    task: URLSessionTask,
                    didCompleteWithError error: Error?) {
        guard let articleID = extractArticleID(from: task.originalRequest?.url?.path ?? "") else { return }
        
        defer {
            statusCodes.removeValue(forKey: task.taskIdentifier)
            responseData.removeValue(forKey: task.taskIdentifier)
            cleanupTask(for: articleID)
        }
        
        if let error = error {
            completionHandlers[articleID]?(.failure(error))
            return
        }
        
        // Check both status code and response data for errors
        if let statusCode = statusCodes[task.taskIdentifier], statusCode >= 400 {
            completionHandlers[articleID]?(.failure(URLError(.badServerResponse)))
            return
        }
        
        // Check response data for error message
        if let data = responseData[task.taskIdentifier],
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let hasError = json["error"] as? Bool,
           hasError {
            completionHandlers[articleID]?(.failure(URLError(.badServerResponse)))
            return
        }
        
        completionHandlers[articleID]?(.success(()))
    }
}

// MARK: - Article Uploader
actor PlanetArticleUploader {
    static let shared = PlanetArticleUploader()
    private var isCreating = false
    
    private init() {
        debugPrint("📤 [Upload] PlanetArticleUploader initialized")
    }
    
    var isArticleCreating: Bool {
        isCreating
    }
    
    func createArticle(title: String, content: String, attachments: [PlanetArticleAttachment], forPlanet planet: Planet) async throws {
        guard !isCreating else {
            throw PlanetError.ArticleCreationInProgressError
        }
        
        isCreating = true
        defer { isCreating = false }
        
        debugPrint("📤 [Upload] Starting createArticle")
        
        let request = try await PlanetManager.shared.createRequest(
            with: "/v0/planets/my/\(planet.id)/articles",
            method: "POST"
        )
        
        let form = self.createMultipartForm(title: title, content: content, attachments: attachments)
        
        try await withCheckedThrowingContinuation { continuation in
            debugPrint("📤 Setting up upload continuation")
            
            PlanetBackgroundArticleUploader.shared.upload(
                request: request,
                form: form,
                articleID: "articles"
            ) { result in
                debugPrint("📤 Upload completion received")
                
                switch result {
                    case .success:
                        debugPrint("📤 Upload succeeded")
                        Task {
                            try? await PlanetShareManager.shared.donatePost(
                                forPlanet: planet,
                                content: title + " " + content
                            )
                            await MainActor.run {
                                NotificationCenter.default.post(name: .reloadArticles, object: nil)
                            }
                        }
                        continuation.resume()
                    case .failure(let error):
                        debugPrint("📤 Upload failed: \(error)")
                        continuation.resume(throwing: error)
                }
            }
        }
        
        debugPrint("📤 [Upload] createArticle completed")
    }
    
    func modifyArticle(id: String, title: String, content: String, attachments: [PlanetArticleAttachment], planetID: String) async throws {
        let editKey = String.editingArticleKey(byID: id)
        await MainActor.run {
            UserDefaults.standard.setValue(1, forKey: editKey)
            NotificationCenter.default.post(name: .startEditingArticle(byID: id), object: nil)
        }
        
        let request = try await PlanetManager.shared.createRequest(
            with: "/v0/planets/my/\(planetID)/articles/\(id)",
            method: "POST"
        )
        
        let form = self.createMultipartForm(title: title, content: content, attachments: attachments)
        
        try await withCheckedThrowingContinuation { continuation in
            PlanetBackgroundArticleUploader.shared.upload(
                request: request,
                form: form,
                articleID: id
            ) { result in
                // Always clean up the edit state
                Task { @MainActor in
                    UserDefaults.standard.removeObject(forKey: editKey)
                    NotificationCenter.default.post(name: .endEditingArticle(byID: id), object: nil)
                    NotificationCenter.default.post(name: .reloadArticle(byID: id), object: nil)
                }
                
                switch result {
                    case .success:
                        Task {
                            do {
                                try await PlanetArticleDownloader.shared.download(
                                    byArticleID: id,
                                    andPlanetID: planetID,
                                    forceDownloadAttachments: true
                                )
                                await MainActor.run {
                                    NotificationCenter.default.post(name: .reloadArticles, object: nil)
                                    NotificationCenter.default.post(name: .updatePlanets, object: nil)
                                }
                            } catch {
                                debugPrint("failed to download article \(id): \(error)")
                            }
                        }
                        continuation.resume()
                    case .failure(let error):
                        continuation.resume(throwing: error)
                }
            }
        }
    }
    
    private func createMultipartForm(title: String, content: String, attachments: [PlanetArticleAttachment]) -> MultipartForm {
        var form = MultipartForm(parts: [
            MultipartForm.Part(name: "title", value: title),
            MultipartForm.Part(name: "date", value: Date().ISO8601Format()),
            MultipartForm.Part(name: "content", value: content)
        ])
        
        for (index, attachment) in attachments.enumerated() {
            if let attachmentData = try? Data(contentsOf: attachment.url) {
                let formData = MultipartForm.Part(
                    name: "attachments[\(index)]",
                    data: attachmentData,
                    filename: attachment.url.lastPathComponent,
                    contentType: attachment.url.mimeType()
                )
                form.parts.append(formData)
            }
        }
        
        return form
    }
    
}
