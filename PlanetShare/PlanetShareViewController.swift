//
//  PlanetShareViewController.swift
//  PlanetShare
//

import UIKit
import SwiftUI
import UniformTypeIdentifiers


class PlanetShareViewController: UIViewController {
    static let closeNotification: Notification.Name = Notification.Name("PlanetShareCloseShareViewNotification")
    
    override func viewDidLoad() {
        super.viewDidLoad()
        guard let context = self.extensionContext else {
            close()
            return
        }
        debugPrint("context: \(context), input items count: \(context.inputItems.count)")
        guard let item = context.inputItems.first as? NSExtensionItem else {
            close()
            return
        }
        debugPrint("first input item: \(item), attachments count: \(item.attachments?.count ?? 0)")
        guard let itemProvider = item.attachments?.first as? NSItemProvider else {
            close()
            return
        }
        debugPrint("first provider attachment: \(itemProvider)")
        Task { @MainActor in
            do {
                try await self.processItem(item: itemProvider)
            } catch {
                debugPrint("failed to process shared item: \(error)")
                self.close()
            }
        }
        NotificationCenter.default.addObserver(forName: Self.closeNotification, object: nil, queue: nil) { _ in
            self.close()
        }
    }
    
    @MainActor
    func processItem(item: NSItemProvider) async throws {
        // MARK: TODO: handle shared photo (1 photo at a time) from Photos.app
        debugPrint("about to process item: \(item)")
        if item.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
            let previewText = try await item.loadItem(forTypeIdentifier: UTType.plainText.identifier) as? String
            if let previewText, !isContentEmpty(content: previewText) {
                showShareView(withContent: previewText, andImage: nil)
            } else {
                throw ShareError.noContent
            }
        } else if item.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
            let imageURL = try await loadFileRepresentation(provider: item, typeIdentifier: UTType.image.identifier)
            let imageName = imageURL.lastPathComponent
            do {
                let (data, _) = try await URLSession.shared.data(from: imageURL)
                let image = UIImage(data: data)
                showShareView(withContent: imageName, andImage: image)
            } catch {
                showShareView(withContent: imageURL.absoluteString, andImage: nil)
            }
        } else if item.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
            let itemURL = try await loadItem(provider: item, typeIdentifier: UTType.url.identifier)
            if isImageByUTType(url: itemURL) {
                do {
                    let (data, _) = try await URLSession.shared.data(from: itemURL)
                    let image = UIImage(data: data)
                    let imageName = itemURL.lastPathComponent
                    showShareView(withContent: imageName, andImage: image)
                } catch {
                    showShareView(withContent: itemURL.absoluteString, andImage: nil)
                }
            } else {
                let previewImage = try? await loadItemPreview(provider: item)
                showShareView(withContent: itemURL.absoluteString, andImage: previewImage)
            }
        } else {
            debugPrint("Unable to process item: \(item) for now, abort.")
            throw ShareError.unknown
        }
    }
    
    func showShareView(withContent content: String, andImage image: UIImage?) {
        DispatchQueue.main.async {
            let contentView = UIHostingController(rootView: PlanetShareView(content: content, image: image))
            self.addChild(contentView)
            self.view.addSubview(contentView.view)
            contentView.view.translatesAutoresizingMaskIntoConstraints = false
            contentView.view.topAnchor.constraint(equalTo: self.view.topAnchor).isActive = true
            contentView.view.bottomAnchor.constraint (equalTo: self.view.bottomAnchor).isActive = true
            contentView.view.leftAnchor.constraint(equalTo: self.view.leftAnchor).isActive = true
            contentView.view.rightAnchor.constraint (equalTo: self.view.rightAnchor).isActive = true
        }
    }
    
    func close() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
        }
    }
}


extension PlanetShareViewController {
    private func loadFileRepresentation(provider: NSItemProvider, typeIdentifier: String) async throws -> URL {
        return try await withCheckedThrowingContinuation { continuation in
            provider.loadFileRepresentation(forTypeIdentifier: typeIdentifier) { url, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let url {
                    continuation.resume(returning: url)
                } else {
                    continuation.resume(throwing: NSError(domain: "InvalidURL", code: -1, userInfo: nil))
                }
            }
        }
    }
    
    private func loadItem(provider: NSItemProvider, typeIdentifier: String) async throws -> URL {
        return try await withCheckedThrowingContinuation { continuation in
            provider.loadItem(forTypeIdentifier: typeIdentifier, options: nil) { item, error in
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
    
    private func loadItemPreview(provider: NSItemProvider) async throws -> UIImage {
        return try await withCheckedThrowingContinuation { continuation in
            provider.loadPreviewImage { item, error in
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
    
    private func isImageByUTType(url: URL) -> Bool {
        guard let fileUTType = UTType(filenameExtension: url.pathExtension) else {
            return false
        }
        return fileUTType.conforms(to: .image)
    }
    
    private func isContentEmpty(content: String) -> Bool {
        return content == "" || content.components(separatedBy: .whitespacesAndNewlines).joined() == ""
    }
}


enum ShareError: Error {
    case noContent
    case unknown
}


extension NSItemProvider: @unchecked Sendable {}
