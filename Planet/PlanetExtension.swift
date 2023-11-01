//
//  PlanetExtension.swift
//  Planet
//
//  Created by Kai on 2/16/23.
//

import Foundation
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
    static let reloadPlanets = Notification.Name("PlanetReloadPlanetsNotification")
    static let reloadArticles = Notification.Name("PlanetReloadArticlesNotification")
    static let addAttachment = Notification.Name("PlanetArticleAddAttachmentNotification")
    static let insertAttachment = Notification.Name("PlanetArticleInsertAttachmentNotification")
    static func reloadPlanetAvatar(forID id: String) -> Self {
        return Notification.Name("PlanetReloadPlanet-" + id + "-" + "Notification")
    }
}


extension NSError {
    static let serverIsInactive = NSError(domain: "planet.error", code: 10000)
    static let serverAuthenticationInvalid = NSError(domain: "planet.error", code: 10001)
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
