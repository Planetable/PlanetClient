import Foundation
import SwiftUI


struct PlanetArticle: Codable, Identifiable {
    let id: String
    let created: Date
    let title: String?
    let content: String?
    let summary: String?
    let link: String
    let attachments: [String]?
    var planetID: UUID?

    var shareLink: URL? {
        if let planetID, let planet = Planet.getPlanet(forID: planetID.uuidString), let ipns = planet.ipns {
            return URL(string: "https://\(ipns).ipfs2.eth.limo/\(id)/")
        }
        return nil
    }
}

struct PlanetArticleAttachment: Equatable {
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
