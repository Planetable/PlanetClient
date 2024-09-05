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
        // MARK: TODO: we should check for image attachment first, otherwise the process may crash if sharing a photo.
        let previewImage = try? await item.loadPreviewImage() as? UIImage
        let previewURL = try? await item.loadItem(forTypeIdentifier: UTType.url.identifier) as? URL
        let previewText = try? await item.loadItem(forTypeIdentifier: UTType.plainText.identifier) as? String
        let content: String = {
            if let previewText, let previewURL {
                return previewText + "\n" + previewURL.absoluteString
            } else if let previewURL {
                return previewURL.absoluteString
            } else if let previewText {
                return previewText
            } else {
                return ""
            }
        }()
        if previewImage == nil && content == "" {
            throw ShareError.noContent
        }
        showShareView(withContent: content, andImage: previewImage)
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
        }
    }
}


enum ShareError: Error {
    case noContent
    case unknown
}


extension NSItemProvider: @unchecked Sendable {}
