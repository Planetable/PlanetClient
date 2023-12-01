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

    var shareLink: URL? {
        // MARK: TODO: a share link for both offline mode and normal mode.
        return nil
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

/// Info returned from /v0/info
struct PlanetServerInfo: Codable {
    var hostName: String // Host name
    var version: String // Planet version
    var ipfsPeerID: String
    var ipfsVersion: String // IPFS (Kubo) version
    var ipfsPeerCount: Int
}