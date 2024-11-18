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
    static let removeAttachment = Notification.Name("PlanetArticleRemoveAttachmentNotification")
    static let updateServerStatus = Notification.Name("PlanetUpdateServerStatusNotification")
    
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

    func processForMobile(maxDimension: CGFloat = 1440, quality: CGFloat = 0.6) -> (image: UIImage, data: Data)? {
        // Calculate new size maintaining aspect ratio
        let scale = min(maxDimension / size.width, maxDimension / size.height, 1.0)
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        // Perform resize and strip EXIF in one render pass
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let processedImage = renderer.image { context in
            draw(in: CGRect(origin: .zero, size: newSize))
        }
        // Convert to JPEG data
        guard let imageData = processedImage.jpegData(compressionQuality: quality) else {
            return nil
        }
        return (processedImage, imageData)
    }

    func processForMobileExtension(maxDimension: CGFloat = 1024, quality: CGFloat = 0.6) -> (image: UIImage, data: Data)? {
        // Calculate the scale factor to maintain aspect ratio and limit dimensions
        let scale = min(maxDimension / size.width, maxDimension / size.height, 1.0)
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)

        // Ensure the UIImage has a valid CGImage
        guard let cgImage = self.cgImage else { return nil }

        // Configure Core Graphics context for resizing
        guard let context = CGContext(
            data: nil,
            width: Int(newSize.width),
            height: Int(newSize.height),
            bitsPerComponent: cgImage.bitsPerComponent,
            bytesPerRow: 0,
            space: cgImage.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: cgImage.bitmapInfo.rawValue
        ) else { return nil }

        // Set high-quality interpolation for resizing
        context.interpolationQuality = .high

        // Perform the resize operation
        context.draw(cgImage, in: CGRect(origin: .zero, size: newSize))

        // Extract the resized image from the context
        guard let resizedCGImage = context.makeImage() else { return nil }
        let resizedImage = UIImage(cgImage: resizedCGImage)

        // Convert the resized image to JPEG format with specified quality
        guard let imageData = resizedImage.jpegData(compressionQuality: quality) else { return nil }

        return (resizedImage, imageData)
    }}

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

// MARK: - TimeInterval -
extension TimeInterval {
    static let pingTimeout: TimeInterval = 5
    static let requestTimeout: TimeInterval = 10
    static let extensionInitDelay: TimeInterval = 2.5
}
