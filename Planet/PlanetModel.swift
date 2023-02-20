//
//  PlanetModel.swift
//  Planet
//
//  Created by Kai on 2/16/23.
//

import Foundation
import SwiftUI


enum PlanetAppTab: Int, Hashable {
    case latest
    case myPlanets
    case settings
    
    func name() -> String {
        switch self {
            case .latest:
                return "Latest"
            case .myPlanets:
                return "My Planets"
            case .settings:
                return "Settings"
        }
    }
}


struct Planet: Codable, Identifiable {
    let id: UUID
    let created: Date
    let updated: Date
    let name: String
    let about: String
    let templateName: String
    let lastPublished: Date?
    let lastPublishedCID: String?
    let ipns: String?
    
    static func empty() -> Self {
        return .init(id: UUID(), created: Date(), updated: Date(), name: "", about: "", templateName: "", lastPublished: Date(), lastPublishedCID: "", ipns: "")
    }
}


struct PlanetArticle: Codable, Identifiable {
    let id: UUID
    let created: Date
    let title: String
    let content: String
    let summary: String
    let link: String
    let attachments: [String]
    var planetID: UUID?
    
    static func empty() -> Self {
        return .init(id: UUID(), created: Date(), title: "", content: "", summary: "", link: "", attachments: [])
    }
}
