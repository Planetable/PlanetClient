//
//  PlanetQuickShareViewController.swift`
//  PlanetShare
//

import UIKit
import Social
import Intents
import UniformTypeIdentifiers


class PlanetQuickShareViewController: SLComposeServiceViewController {

    private var targetItemProvider: NSItemProvider?

    override func viewDidLoad() {
        super.viewDidLoad()
        guard let context = self.extensionContext else {
            return
        }
        guard let item = context.inputItems.first as? NSExtensionItem else {
            return
        }
        guard let itemProvider = item.attachments?.first as? NSItemProvider else {
            return
        }
        self.targetItemProvider = itemProvider
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
        guard let targetItemProvider = self.targetItemProvider else { return }

        // get current planet from context
        let intent = self.extensionContext?.intent as? INSendMessageIntent
        guard let intent, let planetID = intent.conversationIdentifier else { return }
        guard let planet = PlanetAppViewModel.shared.myPlanets.first(where: { $0.id == planetID }) else { return }

        // process share content from item provider, plain text content, url, images, or all of them.
        var content: String = ""
        var attachments: [PlanetArticleAttachment] = []

        // Process plain text
        if targetItemProvider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
            if let text = try await targetItemProvider.loadItem(forTypeIdentifier: UTType.plainText.identifier) as? String {
                content += text
            }
        }

        // Process URLs
        if targetItemProvider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
            if let url = try await targetItemProvider.loadItem(forTypeIdentifier: UTType.url.identifier) as? URL {
                // Check if the URL points to an image
                if let image = try? await loadImage(from: url) {
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
        }

        debugPrint("content: \(content), attachments: \(attachments)")

        // MARK: TODO: where's user updated inputs?

        // Share via planet manager
        try await PlanetManager.shared.createArticle(title: "", content: content, attachments: attachments, forPlanet: planet)
        debugPrint("successfully posted to target planet")
    }

    private func loadPreviewImage() async throws -> UIImage? {
        guard let targetItemProvider = self.targetItemProvider else { return nil }

        // Check for image type
        if targetItemProvider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
            if let image = try await targetItemProvider.loadItem(forTypeIdentifier: UTType.image.identifier) as? UIImage {
                return image
            }
        }

        // Check for URL type
        if targetItemProvider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
            if let url = try await targetItemProvider.loadItem(forTypeIdentifier: UTType.url.identifier) as? URL {
                // Attempt to fetch image from URL
                let (data, _) = try await URLSession.shared.data(from: url)
                if let image = UIImage(data: data) {
                    return image
                }
            }
        }

        return nil
    }

    private func loadImage(from url: URL) async throws -> UIImage? {
        let (data, _) = try await URLSession.shared.data(from: url)
        return UIImage(data: data)
    }

}
