//
//  Planet.swift
//  Planet
//
//  Created by Xin Liu on 11/3/23.
//

import Foundation
import SwiftUI
import PlanetSiteTemplates

enum PlanetAvatarSize {
    case small  // 24
    case medium  // 48
    case large  // 96

    var size: CGSize {
        switch self {
        case .small:
            return CGSize(width: 24, height: 24)
        case .medium:
            return CGSize(width: 48, height: 48)
        case .large:
            return CGSize(width: 96, height: 96)
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
        guard let planetPath = PlanetManager.shared.getPlanetPath(forID: planetID) else { return nil }
        let planetInfoPath = planetPath.appending(path: "planet.json")
        guard FileManager.default.fileExists(atPath: planetInfoPath.path) else { return nil }
        do {
            let data = try Data(contentsOf: planetInfoPath)
            let decoder = JSONDecoder()
            let planet = try decoder.decode(Planet.self, from: data)
            return planet
        } catch {
            debugPrint("failed to get planet data: \(error), at: \(planetInfoPath)")
        }
        return nil
    }

    var nameInitials: String {
        let initials = name.components(separatedBy: .whitespaces).map { $0.prefix(1).capitalized }
            .joined()
        return String(initials.prefix(2))
    }

    var avatarURL: URL? {
        if let url = localAvatarURL(), FileManager.default.fileExists(atPath: url.path) {
            return url
        }
        return remoteAvatarURL()
    }

    func reloadTemplate() {
        guard let template = PlanetManager.shared.templates.first(where: { $0.name == self.templateName }) else { return }
        guard let planetPath = PlanetManager.shared.getPlanetPath(forID: self.id) else { return }
        let templateInfoPath = planetPath.appending(path: "template.json")
        let templateAssetsPath = planetPath.appending(path: "assets")
        if FileManager.default.fileExists(atPath: templateInfoPath.path) {
            let decoder = JSONDecoder()
            if let data = try? Data(contentsOf: templateInfoPath) {
                let t = try? decoder.decode(BuiltInTemplate.self, from: data)
                if let existingTemplateBuildNumber = template.buildNumber, let buildNumber = t?.buildNumber, buildNumber <= existingTemplateBuildNumber {
                    return
                }
            }
        }
        try? FileManager.default.removeItem(at: templateAssetsPath)
        try? FileManager.default.copyItem(at: template.assets, to: templateAssetsPath)
        let encoder = JSONEncoder()
        let data = try? encoder.encode(template)
        try? data?.write(to: templateInfoPath)
        debugPrint("reloaded template: \(template), for planet: \(self.name), at: \(planetPath), template info: \(templateInfoPath)")
    }

    @ViewBuilder
    func listItemView(showCheckmark: Bool = false) -> some View {
        HStack(spacing: 12) {
            avatarView(.medium)
            VStack {
                Text(self.name)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(self.about == "" ? "No description" : self.about)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .foregroundColor(self.about == "" ? .secondary.opacity(0.5) : .secondary)
            }
            .alignmentGuide(.listRowSeparatorLeading) { _ in
                0
            }
            .multilineTextAlignment(.leading)
            if showCheckmark {
                Image(systemName: "checkmark.circle.fill")
                    .renderingMode(.original)
                    .frame(width: 8, height: 8)
            }
        }
        .contentShape(Rectangle())
        .frame(
            maxWidth: .infinity,
            minHeight: 48,
            idealHeight: 48,
            maxHeight: 96,
            alignment: .leading
        )
    }

    @ViewBuilder
    func avatarView(_ size: PlanetAvatarSize) -> some View {
        PlanetAvatarView(planet: self, size: size.size)
    }

    @ViewBuilder
    func avatarView(size: CGSize) -> some View {
        Group {
            if let avatarURL = avatarURL {
                AsyncImage(url: avatarURL) { image in
                    image
                        .interpolation(.high)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: size.width, height: size.height)
                        .clipShape(.circle)
                } placeholder: {
                    planetAvatarPlaceholder(size: size)
                }
                .frame(width: size.width, height: size.height)
                .overlay(
                    RoundedRectangle(cornerRadius: size.width / 2)
                        .stroke(Color("BorderColor"), lineWidth: 0.5)
                )
                .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: 1)
            } else {
                planetAvatarPlaceholder(size: size)
            }
        }
    }

    @ViewBuilder
    func planetAvatarPlaceholder(size: CGSize) -> some View {
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

    // MARK: -
    private func localAvatarURL() -> URL? {
//        guard let nodeID = PlanetAppViewModel.shared.currentNodeID,
//            let documentsDirectory = FileManager.default.urls(
//                for: .documentDirectory,
//                in: .userDomainMask
//            ).first
//        else {
//            return nil
//        }
        guard let nodeID = PlanetAppViewModel.shared.currentNodeID, let documentsDirectory = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: .appGroupName) else {
            return nil
        }
        let myPlanetPath = documentsDirectory
            .appending(path: nodeID)
            .appending(path: "My")
            .appending(path: self.id)
        if !FileManager.default.fileExists(atPath: myPlanetPath.path) {
            do {
                try FileManager.default.createDirectory(
                    at: myPlanetPath,
                    withIntermediateDirectories: true
                )
                debugPrint("Created directory for my planet: \(myPlanetPath)")
            } catch {
                debugPrint("Failed to create directory for my planet: \(error)")
                return nil
            }
        }
        return myPlanetPath.appending(path: "avatar.png")
    }

    private func remoteAvatarURL() -> URL? {
        guard let serverURL = URL(string: PlanetAppViewModel.shared.currentServerURLString) else {
            return nil
        }
        return serverURL
            .appending(path: self.id)
            .appending(path: "avatar.png")
    }
}
