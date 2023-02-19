//
//  PlanetExtension.swift
//  Planet
//
//  Created by Kai on 2/16/23.
//

import Foundation


extension String {
    static let settingsSelectedTabKey = "PlanetSettingsSelectedTabKey"
    static let settingsServerURLKey = "PlanetSettingsServerURLKey"
    static let settingsServerAuthenticationEnabledKey = "PlanetSettingsServerAuthenticationEnabledKey"
    static let settingsServerUsernameKey = "PlanetSettingsServerUsernameKey"
    static let settingsServerPasswordKey = "PlanetSettingsServerPasswordKey"
}


extension URL {
    static let myPlanetsList = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!.appendingPathComponent("myplanets.json")
}


extension Notification.Name {
    static let reloadPlanets = Notification.Name("PlanetReloadPlanetsNotification")
}


extension NSError {
    static let serverIsInactive = NSError(domain: "planet.error", code: 10000)
}
