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


struct Planet: Codable, Identifiable, Hashable {
    let id: String
    let created: Date
    let updated: Date
    let name: String
    let about: String
    let templateName: String
    let lastPublished: Date?
    let lastPublishedCID: String?
    let ipns: String?
    
    static func empty() -> Self {
        return .init(id: UUID().uuidString, created: Date(), updated: Date(), name: "", about: "", templateName: "", lastPublished: Date(), lastPublishedCID: "", ipns: "")
    }

    var nameInitials: String {
        let initials = name.components(separatedBy: .whitespaces).map { $0.prefix(1).capitalized }
            .joined()
        return String(initials.prefix(2))
    }
}


struct PlanetArticle: Codable, Identifiable {
    let id: String
    let created: Date
    let title: String
    let content: String
    let summary: String?
    let link: String
    let attachments: [String]?
    var planetID: UUID?
    
    static func empty() -> Self {
        return .init(id: UUID().uuidString, created: Date(), title: "", content: "", summary: "", link: "", attachments: [])
    }
}


struct PlanetArticleAttachment {
    let id: UUID
    let created: Date
    let image: UIImage
    let url: URL
    
    func markdownImageValue() -> String {
        return """
\n<img alt="\(url.deletingPathExtension().lastPathComponent)" src="\(url.lastPathComponent)">\n
"""
    }
}
