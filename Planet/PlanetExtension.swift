//
//  PlanetExtension.swift
//  Planet
//
//  Created by Kai on 2/16/23.
//

import Foundation
import UIKit
import MobileCoreServices
import UniformTypeIdentifiers


extension String {
    static let settingsSelectedTabKey = "PlanetSettingsSelectedTabKey"
    static let settingsServerURLKey = "PlanetSettingsServerURLKey"
    static let settingsServerProtocolKey = "PlanetSettingsServerProtocolKey"
    static let settingsServerHostKey = "PlanetSettingsServerHostKey"
    static let settingsServerPortKey = "PlanetSettingsServerPortKey"
    static let settingsServerAuthenticationEnabledKey = "PlanetSettingsServerAuthenticationEnabledKey"
    static let settingsServerUsernameKey = "PlanetSettingsServerUsernameKey"
    static let settingsServerPasswordKey = "PlanetSettingsServerPasswordKey"
    static let settingsNodeIDKey = "PlanetSettingsNodeIDKey"
    
    static func editingArticleKey(byID id: String) -> String {
        return "PlanetEditingArticleKey-\(id)"
    }
}


extension URL {
    static let myPlanetsList = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!.appending(path: "myplanets.json")
    
    func mimeType() -> String {
        if let mimeType = UTType(filenameExtension: self.pathExtension)?.preferredMIMEType {
            return mimeType
        } else {
            return "application/octet-stream"
        }
    }
}


extension Notification.Name {
    static let updatePlanets = Notification.Name("PlanetUpdatePlanetsNotification")
    static let reloadArticles = Notification.Name("PlanetReloadArticlesNotification")
    static let addAttachment = Notification.Name("PlanetArticleAddAttachmentNotification")
    static let insertAttachment = Notification.Name("PlanetArticleInsertAttachmentNotification")
    
    static func startEditingArticle(byID id: String) -> Notification.Name {
        return Notification.Name("PlanetStartEditingArticleNotification-\(id)")
    }
    
    static func endEditingArticle(byID id: String) -> Notification.Name {
        return Notification.Name("PlanetEndEditingArticleNotification-\(id)")
    }

    static func reloadArticle(byID id: String) -> Notification.Name {
        return Notification.Name("PlanetReloadArticleNotification-\(id)")
    }

    static func reloadAvatar(byID id: String) -> Notification.Name {
        return Notification.Name("PlanetReloadAvatarNotification-\(id)")
    }
}


extension Date {
    func mmddyyyy() -> String {
        let format = DateFormatter()
        format.dateStyle = .medium
        format.timeStyle = .none
        return format.string(from: self)
    }
}


extension Data {
    mutating func append(_ string: String) {
        self.append(string.data(using: .utf8, allowLossyConversion: true)!)
    }
}


extension UIImage {
    func resizeToSquare(size: CGSize) -> UIImage? {
        let originalSize = self.size
        let smallestDimension = min(originalSize.width, originalSize.height)
        let squareOrigin = CGPoint(x: (originalSize.width - smallestDimension) / 2.0, y: (originalSize.height - smallestDimension) / 2.0)
        let squareSize = CGSize(width: smallestDimension, height: smallestDimension)
        let squareCroppedImage = self.cgImage?.cropping(to: CGRect(origin: squareOrigin, size: squareSize))
        let renderer = UIGraphicsImageRenderer(size: size)
        let resizedImage = renderer.image { _ in
            UIImage(cgImage: squareCroppedImage!).draw(in: CGRect(origin: .zero, size: size))
        }
        return resizedImage
    }

    func removeEXIF() -> UIImage? {
        guard let imageData = self.pngData() else {
            return nil
        }
        guard let source = CGImageSourceCreateWithData(imageData as CFData, nil) else {
            return nil
        }
        let mutableData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(mutableData, "public.png" as CFString, 1, nil) else {
            return nil
        }
        CGImageDestinationAddImageFromSource(destination, source, 0, nil)
        CGImageDestinationFinalize(destination)
        guard let image = UIImage(data: mutableData as Data) else {
            return nil
        }
        return image
    }
}
