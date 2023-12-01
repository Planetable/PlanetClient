//
//  PlanetLatestItemView.swift
//  Planet
//
//  Created by Kai on 2/20/23.
//

import SwiftUI

struct PlanetLatestItemView: View {
    var planet: Planet
    var article: PlanetArticle
    var showAvatar: Bool = true

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if showAvatar {
                planet.avatarView(.medium)
            }
            VStack(alignment: .leading, spacing: 4) {
                VStack(alignment: .leading) {
                    if article.title.count > 0, article.content.count > 0 {
                        // With both title and content
                        Text(article.title)
                            .font(.headline)
                            .foregroundColor(.primary)
                        Text(article.content.prefix(280))
                            .foregroundColor(.secondary)

                    }
                    else if article.title.count == 0, article.content.count > 0 {
                        // With only content
                        Text(article.content.prefix(280))
                            .lineLimit(2)
                            .foregroundColor(.secondary)
                    }
                    else if article.title.count > 0, article.content.count == 0 {
                        // With only title
                        Text(article.title)
                            .font(.headline)
                            .lineLimit(2)
                            .foregroundColor(.primary)
                    }
                    else if let attachments = article.attachments, attachments.count > 0 {
                        // With only attachments
                        Text(attachmentsLabel())
                            .lineLimit(2)
                            .foregroundColor(.secondary)
                    }
                    else {
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
            try? await PlanetManager.shared.downloadArticle(id: article.id, planetID: planet.id)
        }
    }

    private func attachmentsLabel() -> String {
        if let attachments = article.attachments, attachments.count > 0 {
            if attachments.count == 1 {
                return attachments[0]
            }
            else {
                return "\(attachments[0]) & \(attachments.count - 1) more"
            }
        }
        return ""
    }
}
