//
//  PlanetExtension.swift
//  Planet
//
//  Created by Kai on 2/16/23.
//

import Foundation
import UIKit
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
    static let myPlanetsList = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!.appendingPathComponent("myplanets.json")
    
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
}
