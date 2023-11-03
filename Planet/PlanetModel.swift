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
    
    static func getPlanet(forID planetID: String) -> Self? {
        if let planetPath = PlanetManager.shared.getPlanetPath(forID: planetID), let planetData = FileManager.default.contents(atPath: planetPath.appendingPathComponent("planet.json").path) {
            do {
                let planet = try JSONDecoder().decode(Planet.self, from: planetData)
                return planet
            } catch {
                print("Error decoding planet: \(error)")
            }
        } else {
            print("Error getting planet path for ID: \(planetID)")
        }
        return nil
    }

    static func empty() -> Self {
        return .init(id: UUID().uuidString, created: Date(), updated: Date(), name: "", about: "", templateName: "", lastPublished: Date(), lastPublishedCID: "", ipns: "")
    }

    var nameInitials: String {
        let initials = name.components(separatedBy: .whitespaces).map { $0.prefix(1).capitalized }
            .joined()
        return String(initials.prefix(2))
    }

    var avatarURL: URL? {
        return localAvatarURL()
    }

    private func localAvatarURL() -> URL? {
        guard let nodeID = PlanetAppViewModel.shared.currentNodeID,
              let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        let myPlanetPath = documentsDirectory.appendingPathComponent(nodeID).appendingPathComponent("My").appendingPathComponent(self.id)
        if !FileManager.default.fileExists(atPath: myPlanetPath.path) {
            do {
                try FileManager.default.createDirectory(at: myPlanetPath, withIntermediateDirectories: true)
                debugPrint("Created directory for my planet: \(myPlanetPath)")
            } catch {
                debugPrint("Failed to create directory for my planet: \(error)")
                return nil
            }
        }
        return myPlanetPath.appendingPathComponent("avatar.png")
    }
    
    private func remoteAvatarURL() -> URL? {
        guard let serverURL = URL(string: PlanetSettingsViewModel.shared.serverURL) else {
            return nil
        }
        return serverURL
            .appendingPathComponent("/v0/planets/my/")
            .appendingPathComponent(self.id)
            .appendingPathComponent("/public/avatar.png")
    }

    @ViewBuilder
    func avatarView(size: CGSize) -> some View {
        if let avatarURL = avatarURL {
            AsyncImage(url: avatarURL) { image in
                image
                    .interpolation(.high)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .cornerRadius(size.width * 0.5)
            } placeholder: {
                planetAvatarPlaceholder(size: size)
            }
            .frame(width: size.width)
            .overlay(
                RoundedRectangle(cornerRadius: size.width / 2)
                    .stroke(Color("BorderColor"), lineWidth: 0.5)
            )
            .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: 1)    
        } else {
            planetAvatarPlaceholder(size: size)
        }
    }
    
    @ViewBuilder
    private func planetAvatarPlaceholder(size: CGSize) -> some View {
        Text(self.nameInitials)
            .font(Font.custom("Arial Rounded MT Bold", size: size.width / 2))
            .foregroundColor(Color.white)
            .contentShape(Rectangle())
            .frame(width: size.width, height: size.height, alignment: .center)
            .background(
                LinearGradient(
                    gradient: ViewUtils.getPresetGradient(from: UUID(uuidString: self.id)!),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .cornerRadius(size.width / 2)
            .overlay(
                RoundedRectangle(cornerRadius: size.width / 2)
                    .stroke(Color("BorderColor"), lineWidth: 0.5)
            )
            .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: 1)
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
