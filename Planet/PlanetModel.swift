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
        return .init(
            id: UUID().uuidString,
            created: Date(),
            title: "",
            content: "",
            summary: "",
            link: "",
            attachments: []
        )
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
