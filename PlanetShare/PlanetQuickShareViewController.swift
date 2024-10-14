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

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            let intent = self.extensionContext?.intent as? INSendMessageIntent
            if let intent, let planetID = intent.conversationIdentifier, let planet = PlanetAppViewModel.shared.myPlanets.first(where: { $0.id == planetID }) {
                self.setTargetPlanet(planet)
            }
            if let item = self.extensionContext?.inputItems.first as? NSExtensionItem, let itemProviders = item.attachments {
                self.itemProviders = itemProviders
            } else {
                self.itemProviders = []
            }
            self.reloadConfigurationItems()
        }
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
        if let planet = self.getTargetPlanet() ?? PlanetAppViewModel.shared.myPlanets.first {
            let item = SLComposeSheetConfigurationItem()
            item?.title = "Share to \(planet.name)"
            item?.tapHandler = {
                self.setTargetPlanet(planet)
                self.showPlanetPicker()
            }
            if let item {
                return [item]
            }
        }
        return []
    }

    // MARK: -

    private func showPlanetPicker() {
        let controller = UIAlertController(title: "Select Planet", message: nil, preferredStyle: .actionSheet)
        for planet in PlanetAppViewModel.shared.myPlanets {
            let action = UIAlertAction(title: planet.name, style: .default) { _ in
                self.setTargetPlanet(planet)
                self.reloadConfigurationItems()
            }
            controller.addAction(action)
        }
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { _ in
            self.reloadConfigurationItems()
        }
        controller.addAction(cancelAction)
        self.present(controller, animated: true, completion: nil)
    }

    private func getTargetPlanet() -> Planet? {
        if let planetID = PlanetManager.shared.userDefaults.string(forKey: PlanetShareManager.lastSharedPlanetID), let planet = PlanetAppViewModel.shared.myPlanets.first(where: { $0.id == planetID }) {
            return planet
        }
        return nil
    }

    private func setTargetPlanet(_ planet: Planet) {
        PlanetManager.shared.userDefaults.setValue(planet.id, forKey: PlanetShareManager.lastSharedPlanetID)
        PlanetManager.shared.userDefaults.synchronize()
    }

    private func postToTargetPlanet() async throws {
        guard let planet = self.getTargetPlanet() else { return }

        let targetItemProviders = self.itemProviders ?? []

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

        // create article, save as draft if failed.
        debugPrint("about to create article")
        do {
            try await PlanetManager.shared.createArticle(title: "", content: content, attachments: attachments, forPlanet: planet)
        } catch {
            debugPrint("failed to create article: \(error), saving as draft.")
            let draftID = UUID()
            _ = try PlanetManager.shared.renderArticlePreview(forTitle: "", content: content, andArticleID: draftID.uuidString)
            let draftAttachments = attachments.map { a in
                return a.url.lastPathComponent
            }
            try? PlanetManager.shared.saveArticleDraft(byID: draftID, attachments: draftAttachments, title: "", content: content, planetID: UUID(uuidString: planet.id))
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
                    let tmpURL = URL.cachesDirectory.appending(path: "\(id.uuidString).png")
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
