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
