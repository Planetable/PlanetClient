//
//  PlanetLatestItemView.swift
//  Planet
//
//  Created by Kai on 2/20/23.
//

import SwiftUI

struct PlanetLatestItemView: View {
    var planet: Planet?
    var article: PlanetArticle
    var showAvatar: Bool = true

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if let planet, showAvatar {
                planet.avatarView(.medium)
            }
            VStack(alignment: .leading, spacing: 4) {
                VStack(alignment: .leading) {
                    if let title = article.title, title.count > 0, let content = article.content, content.count > 0 {
                        // With both title and content
                        Text(title)
                            .font(.headline)
                            .foregroundColor(.primary)
                        Text(content.prefix(280))
                            .foregroundColor(.secondary)

                    } else if let title = article.title, title.count == 0, let content = article.content, content.count > 0 {
                        // With only content
                        Text(content.prefix(280))
                            .lineLimit(2)
                            .foregroundColor(.secondary)
                    } else if let title = article.title, title.count > 0, let content = article.content, content.count == 0 {
                        // With only title
                        Text(title)
                            .font(.headline)
                            .lineLimit(2)
                            .foregroundColor(.primary)
                    } else if let attachments = article.attachments, attachments.count > 0 {
                        // With only attachments
                        Text(attachmentsLabel())
                            .lineLimit(2)
                            .foregroundColor(.secondary)
                    } else {
                        // With no content
                        Spacer()
                    }
                }
                .frame(height: 48)
                HStack(spacing: 6) {
                    Text(article.created.mmddyyyy())
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
        }
        .contentShape(Rectangle())
        .task(id: article.id, priority: .background) {
            guard let planet else { return }
            let articleID: String = article.id
            let planetID: String = planet.id
            do {
                try await PlanetArticleDownloader.shared.download(byArticleID: articleID, andPlanetID: planetID)
            } catch {
                debugPrint("failed to download article \(articleID): \(error)")
            }
        }
    }

    private func attachmentsLabel() -> String {
        if let attachments = article.attachments, attachments.count > 0 {
            if attachments.count == 1 {
                return attachments[0]
            } else {
                return "\(attachments[0]) & \(attachments.count - 1) more"
            }
        }
        return ""
    }
}
