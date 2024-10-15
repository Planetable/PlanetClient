import Foundation
import UIKit
import SwiftUI
import MobileCoreServices
import UniformTypeIdentifiers

// MARK: - String -
extension String {
    static let appGroupName: String = {
        if let name = Bundle.main.object(forInfoDictionaryKey: "APP_GROUP_NAME") as? String {
            let groupName = "group.\(name)"
            debugPrint("Using APP_GROUP_NAME for shared user defaults and keychain access: \(groupName)")
            return groupName
        }
        fatalError("APP_GROUP_NAME not found in xcconfig")
    }()

    static let selectedPlanetIndex = "PlanetSelectedPlanetIndexKey"
    static let selectedPlanetTemplateName = "PlanetSelectedPlanetTemplateNameKey"
    static let settingsSelectedTabKey = "PlanetSettingsSelectedTabKey"
    static let settingsServerURLKey = "PlanetSettingsServerURLKey"
    static let settingsServerNameKey = "PlanetSettingsServerNameKey"
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

// MARK: - URL -
extension URL {
    func mimeType() -> String {
        if let mimeType = UTType(filenameExtension: self.pathExtension)?.preferredMIMEType {
            return mimeType
        } else {
            return "application/octet-stream"
        }
    }

    func withTimestamp() -> URL? {
        let timestamp = Int(Date().timeIntervalSince1970)
        guard var components = URLComponents(url: self, resolvingAgainstBaseURL: false) else {
            return nil
        }
        var queryItems = components.queryItems ?? []
        queryItems.append(URLQueryItem(name: "t", value: "\(timestamp)"))
        components.queryItems = queryItems
        return components.url
    }
}

// MARK: - Notification -
extension Notification.Name {
    static let updatePlanets = Notification.Name("PlanetUpdatePlanetsNotification")
    static let reloadArticles = Notification.Name("PlanetReloadArticlesNotification")
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

// MARK: - Date -
extension Date {
    func mmddyyyy() -> String {
        let format = DateFormatter()
        format.dateStyle = .medium
        format.timeStyle = .none
        return format.string(from: self)
    }
}

// MARK: - Data -
extension Data {
    mutating func append(_ string: String) {
        self.append(string.data(using: .utf8, allowLossyConversion: true)!)
    }
}

// MARK: - UIImage -
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

// MARK: - Color -
extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 08) & 0xFF) / 255,
            blue: Double((hex >> 00) & 0xFF) / 255,
            opacity: alpha
        )
    }
}
