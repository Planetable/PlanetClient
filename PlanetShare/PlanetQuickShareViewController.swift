//
//  PlanetQuickShareViewController.swift`
//  PlanetShare
//

import Social
import Intents
import UniformTypeIdentifiers
import UIKit


class PlanetQuickShareViewController: SLComposeServiceViewController {
    
    private var itemProviders: [NSItemProvider]?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let _ = PlanetAppViewModel.shared
        let _ = PlanetManager.shared
        guard let context = self.extensionContext else {
            return
        }
        guard let item = context.inputItems.first as? NSExtensionItem else {
            return
        }
        self.itemProviders = item.attachments ?? []
    }
    
    override func isContentValid() -> Bool {
        if PlanetAppViewModel.shared.currentNodeID == nil {
            return false
        }
        return true
    }
    
    override func didSelectPost() {
        Task { @MainActor in
            do {
                try await postToTargetPlanet()
            } catch {
                debugPrint("error posting to target planet: \(error)")
            }
            super.didSelectPost()
        }
    }
    
    override func configurationItems() -> [Any]! {
        return []
    }
    
    // MARK: -
    
    @MainActor
    private func postToTargetPlanet() async throws {
        let targetItemProviders = self.itemProviders ?? []
        
        // get current planet from context
        let intent = self.extensionContext?.intent as? INSendMessageIntent
        guard let intent, let planetID = intent.conversationIdentifier else { return }
        guard let planet = PlanetAppViewModel.shared.myPlanets.first(where: { $0.id == planetID }) else { return }
        
        // process share content from item provider, plain text content, url as text content or images.
        var content: String = self.contentText
        var attachments: [PlanetArticleAttachment] = []
        
        for targetItemProvider in targetItemProviders {
            // Process URLs
            if targetItemProvider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                let url = try await loadURL(from: targetItemProvider)
                // Check if the URL points to an image
                if let image = try? await loadImageFromURL(url) {
                    let attachment = PlanetArticleAttachment(id: UUID(), created: Date(), image: image, url: url)
                    attachments.append(attachment)
                    // Append image name as text content
                    if content.isEmpty {
                        content += url.lastPathComponent
                    }
                } else {
                    // Append the URL as text content
                    if !content.isEmpty {
                        content += "\n"
                    }
                    content += url.absoluteString
                }
            }
            // Process Images
            else if targetItemProvider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                let (image, url) = try await loadImageFromItem(targetItemProvider)
                if let image, let url {
                    let attachment = PlanetArticleAttachment(id: UUID(), created: Date(), image: image, url: url)
                    attachments.append(attachment)
                    if self.contentText == "" {
                        content += url.lastPathComponent + "\n"
                    }
                }
            }
        }
        
        debugPrint("got content: \(content), attachments: \(attachments), from item providers: \(targetItemProviders)")
        
        // Share via planet manager
        try await PlanetManager.shared.createArticle(title: "", content: content, attachments: attachments, forPlanet: planet)
        
        debugPrint("successfully posted to target planet")
    }
    
    private func loadImageFromURL(_ url: URL) async throws -> UIImage? {
        let (data, _) = try await URLSession.shared.data(from: url)
        return UIImage(data: data)
    }
    
    private func loadImageFromItem(_ item: NSItemProvider) async throws -> (UIImage?, URL?) {
        // Check for image type, try to get image directly
        if item.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
            let image = try await loadImage(from: item)
            let id = UUID()
            let tmpPath = NSTemporaryDirectory().appending("\(id.uuidString).png")
            let tmpURL = URL(fileURLWithPath: tmpPath)
            do {
                if let data = image.pngData() {
                    try? FileManager.default.removeItem(at: tmpURL)
                    try data.write(to: tmpURL)
                    return (image, tmpURL)
                }
            } catch {
                debugPrint("failed to load preview view image: \(error)")
            }
        }
        // Check for URL type, try to fetch image from URL
        if item.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
            let url = try await loadURL(from: item)
            let (data, _) = try await URLSession.shared.data(from: url)
            if let image = UIImage(data: data) {
                return (image, url)
            }
        }
        return (nil, nil)
    }
    
    @Sendable private func loadURL(from it: NSItemProvider) async throws -> URL {
        return try await withCheckedThrowingContinuation { continuation in
            it.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { item, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let url = item as? URL {
                    continuation.resume(returning: url)
                } else {
                    continuation.resume(throwing: NSError(domain: "InvalidItem", code: -1, userInfo: nil))
                }
            }
        }
    }
    
    @Sendable private func loadImage(from it: NSItemProvider) async throws -> UIImage {
        return try await withCheckedThrowingContinuation { continuation in
            it.loadPreviewImage { item, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let image = item as? UIImage {
                    continuation.resume(returning: image)
                } else {
                    continuation.resume(throwing: NSError(domain: "InvalidItem", code: -1, userInfo: nil))
                }
            }
        }
    }
}
