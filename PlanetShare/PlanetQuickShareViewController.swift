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
        Task(priority: .userInitiated) {
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
            } else if targetItemProvider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                let (image, url) = try await loadImage(from: targetItemProvider)
                let attachment = PlanetArticleAttachment(id: UUID(), created: Date(), image: image, url: url)
                attachments.append(attachment)
                if self.contentText == "" {
                    content += url.lastPathComponent + "\n"
                }
            }
        }

        // create article if server is active, otherwise save as draft for target planet.
        do {
            try await PlanetManager.shared.createArticle(title: "", content: content, attachments: attachments, forPlanet: planet)
        } catch PlanetError.APIServerIsInactiveError {
            let draftID = UUID()
            _ = try PlanetManager.shared.renderArticlePreview(forTitle: "", content: content, andArticleID: draftID.uuidString)
            let draftAttachments = attachments.map { a in
                return a.url.lastPathComponent
            }
            try PlanetManager.shared.saveArticleDraft(byID: draftID, attachments: draftAttachments, title: "", content: content, planetID: UUID(uuidString: planetID))
        } catch {
            throw error
        }
    }

    private func loadImageFromURL(_ url: URL) async throws -> UIImage? {
        let (data, _) = try await URLSession.shared.data(from: url)
        return UIImage(data: data)
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

    @Sendable private func loadImage(from it: NSItemProvider) async throws -> (UIImage, URL) {
        return try await withCheckedThrowingContinuation { continuation in
            it.loadItem(forTypeIdentifier: UTType.image.identifier, options: nil) { (item, error) in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                if let url = item as? URL {
                    // If the item is a URL, load the image from the file URL
                    if let image = UIImage(contentsOfFile: url.path) {
                        continuation.resume(returning: (image, url))
                    } else {
                        continuation.resume(throwing: NSError(domain: "InvalidItem", code: -1, userInfo: nil))
                    }
                } else if let imageData = item as? Data, let image = UIImage(data: imageData) {
                    let id = UUID()
                    let tmpPath = NSTemporaryDirectory().appending("\(id.uuidString).png")
                    let tmpURL = URL(fileURLWithPath: tmpPath)
                    do {
                        try? FileManager.default.removeItem(at: tmpURL)
                        try imageData.write(to: tmpURL)
                        continuation.resume(returning: (image, tmpURL))
                    } catch {
                        continuation.resume(throwing: NSError(domain: "InvalidItem", code: -1, userInfo: nil))
                    }
                } else {
                    continuation.resume(throwing: NSError(domain: "InvalidItem", code: -1, userInfo: nil))
                }
            }
        }
    }
}
