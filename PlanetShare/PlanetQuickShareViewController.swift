//
//  PlanetQuickShareViewController.swift
//  PlanetShare
//

import Social
import Intents
import UniformTypeIdentifiers
import UIKit


class PlanetQuickShareViewController: SLComposeServiceViewController {
    private var itemProviders: [NSItemProvider] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        initializeSharedInstances()
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            self.setupItemProviders()
            self.reloadConfigurationItems()
            self.validateContent()
        }
    }

    // MARK: - Initialization

    private func initializeSharedInstances() {
        _ = PlanetAppViewModel.shared
        _ = PlanetManager.shared
    }

    // MARK: - Setup Item Providers

    private func setupItemProviders() {
        if let intent = self.extensionContext?.intent as? INSendMessageIntent,
           let planetID = intent.conversationIdentifier,
           let planet = PlanetAppViewModel.shared.myPlanets.first(where: { $0.id == planetID }) {
            self.setTargetPlanet(planet)
        }

        if let item = self.extensionContext?.inputItems.first as? NSExtensionItem,
           let providers = item.attachments {
            self.itemProviders = providers
        }
    }

    // MARK: - Validation and Actions

    override func isContentValid() -> Bool {
        return PlanetAppViewModel.shared.currentNodeID != nil && itemProviders.count > 0
    }

    override func didSelectPost() {
        Task(priority: .userInitiated) {
            do {
                try await postToTargetPlanet()
            } catch {
                debugPrint("Error posting to target planet: \(error)")
            }
            super.didSelectPost()
        }
    }

    override func configurationItems() -> [Any]! {
        guard let planet = self.getTargetPlanet() ?? PlanetAppViewModel.shared.myPlanets.first else { return [] }
        let item = SLComposeSheetConfigurationItem()
        item?.title = "Share to \(planet.name)"
        item?.tapHandler = {
            self.setTargetPlanet(planet)
            self.showPlanetPicker()
        }
        return [item].compactMap { $0 }
    }

    // MARK: - Planet Selection

    private func showPlanetPicker() {
        let controller = UIAlertController(title: "Select Planet", message: nil, preferredStyle: .actionSheet)
        PlanetAppViewModel.shared.myPlanets.forEach { planet in
            let action = UIAlertAction(title: planet.name, style: .default) { _ in
                self.setTargetPlanet(planet)
                self.reloadConfigurationItems()
            }
            controller.addAction(action)
        }
        controller.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(controller, animated: true)
    }

    private func getTargetPlanet() -> Planet? {
        guard let planetID = PlanetManager.shared.userDefaults.string(forKey: PlanetShareManager.lastSharedPlanetID) else { return nil }
        return PlanetAppViewModel.shared.myPlanets.first(where: { $0.id == planetID })
    }

    private func setTargetPlanet(_ planet: Planet) {
        PlanetManager.shared.userDefaults.setValue(planet.id, forKey: PlanetShareManager.lastSharedPlanetID)
        PlanetManager.shared.userDefaults.synchronize()
    }

    // MARK: - Post to Target Planet

    private func postToTargetPlanet() async throws {
        guard let planet = self.getTargetPlanet() else { return }

        var content = self.contentText ?? ""
        var attachments: [PlanetArticleAttachment] = []

        for provider in itemProviders {
            if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                try await processURLProvider(provider, into: &content, attachments: &attachments)
            } else if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                try await processImageProvider(provider, into: &content, attachments: &attachments)
            }
        }

        do {
            try await PlanetManager.shared.createArticle(
                title: "",
                content: content,
                attachments: attachments,
                forPlanet: planet,
                isFromShareExtension: true
            )
        } catch {
            debugPrint("Failed to create article: \(error). Saved as draft.")
        }
    }

    // MARK: - Process Item Providers

    private func processURLProvider(
        _ provider: NSItemProvider,
        into content: inout String,
        attachments: inout [PlanetArticleAttachment]
    ) async throws {
        let url = try await loadURL(from: provider)

        if let (processedImage, tmpURL) = try? await loadImage(from: provider) {
            let attachment = createAttachment(from: processedImage, at: tmpURL)
            attachments.append(attachment)
            appendToContent(&content, value: url.lastPathComponent)
        } else {
            appendToContent(&content, value: url.absoluteString)
        }
    }

    private func processImageProvider(
        _ provider: NSItemProvider,
        into content: inout String,
        attachments: inout [PlanetArticleAttachment]
    ) async throws {
        let (processedImage, tmpURL) = try await loadImage(from: provider)
        let attachment = createAttachment(from: processedImage, at: tmpURL)
        attachments.append(attachment)
    }

    private func appendToContent(_ content: inout String, value: String) {
        content += content.isEmpty ? value : "\n\(value)"
    }

    // MARK: - Image Processing

    private func createAttachment(from image: UIImage, at url: URL) -> PlanetArticleAttachment {
        return PlanetArticleAttachment(
            id: UUID(),
            created: Date(),
            image: image,
            url: url
        )
    }

    @Sendable private func loadImage(from itemProvider: NSItemProvider) async throws -> (UIImage, URL) {
        return try await withCheckedThrowingContinuation { continuation in
            itemProvider.loadItem(forTypeIdentifier: UTType.image.identifier, options: nil) { item, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let item = item else {
                    continuation.resume(throwing: NSError(domain: "InvalidItem", code: -1, userInfo: nil))
                    return
                }

                let tmpURL = URL.cachesDirectory.appendingPathComponent(UUID().uuidString + ".jpg")
                try? FileManager.default.removeItem(at: tmpURL)

                var image: UIImage?

                if let url = item as? URL {
                    image = UIImage(contentsOfFile: url.path)
                } else if let data = item as? Data {
                    image = UIImage(data: data)
                } else if let uiImage = item as? UIImage {
                    image = uiImage
                }

                guard let unwrappedImage = image,
                      let (processedImage, imageData) = unwrappedImage.processForMobileExtension() else {
                    continuation.resume(throwing: NSError(domain: "ProcessingFailed", code: -1, userInfo: nil))
                    return
                }

                do {
                    try imageData.write(to: tmpURL)
                    continuation.resume(returning: (processedImage, tmpURL))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func loadURL(from provider: NSItemProvider) async throws -> URL {
        return try await withCheckedThrowingContinuation { continuation in
            provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { item, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let url = item as? URL {
                    continuation.resume(returning: url)
                } else {
                    continuation.resume(throwing: NSError(domain: "InvalidItem", code: -1))
                }
            }
        }
    }
}
