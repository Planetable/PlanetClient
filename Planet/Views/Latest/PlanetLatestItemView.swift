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
                    Text(article.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    if let summary = article.summary, summary.count > 0 {
                        Text(summary.prefix(280))
                            .foregroundColor(.secondary)
                        if let summary =  article.summary, summary.count < 40 {
                            Spacer()
                        }
                    } else if article.content.count > 0 {
                        Text(article.content.prefix(280))
                            .foregroundColor(.secondary)
                        if article.content.count < 40 {
                            Spacer()
                        }
                    } else {
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
            do {
                try await PlanetManager.shared.downloadArticle(id: article.id, planetID: planet.id)
            } catch {
                debugPrint("failed to download article: \(error)")
            }
        }
    }
}
