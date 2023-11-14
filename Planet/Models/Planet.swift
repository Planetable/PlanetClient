//
//  Planet.swift
//  Planet
//
//  Created by Xin Liu on 11/3/23.
//

import Foundation
import SwiftUI

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
        if let planetPath = PlanetManager.shared.getPlanetPath(forID: planetID),
            let planetData = FileManager.default.contents(
                atPath: planetPath.appendingPathComponent("planet.json").path
            )
        {
            do {
                let planet = try JSONDecoder().decode(Planet.self, from: planetData)
                return planet
            }
            catch {
                print("Error decoding planet: \(error)")
            }
        }
        else {
            print("Error getting planet path for ID: \(planetID)")
        }
        return nil
    }

    static func empty() -> Self {
        return .init(
            id: UUID().uuidString,
            created: Date(),
            updated: Date(),
            name: "",
            about: "",
            templateName: "",
            lastPublished: Date(),
            lastPublishedCID: "",
            ipns: ""
        )
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

    private func localAvatarURL() -> URL? {
        guard let nodeID = PlanetAppViewModel.shared.currentNodeID,
            let documentsDirectory = FileManager.default.urls(
                for: .documentDirectory,
                in: .userDomainMask
            ).first
        else {
            return nil
        }
        let myPlanetPath = documentsDirectory.appendingPathComponent(nodeID).appendingPathComponent(
            "My"
        ).appendingPathComponent(self.id)
        if !FileManager.default.fileExists(atPath: myPlanetPath.path) {
            do {
                try FileManager.default.createDirectory(
                    at: myPlanetPath,
                    withIntermediateDirectories: true
                )
                debugPrint("Created directory for my planet: \(myPlanetPath)")
            }
            catch {
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
        return
            serverURL
            .appendingPathComponent("/v0/planets/my/")
            .appendingPathComponent(self.id)
            .appendingPathComponent("/public/avatar.png")
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
        avatarView(size: size.size)
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
            }
            else {
                planetAvatarPlaceholder(size: size)
            }
        }
        .task(id: id, priority: .background) {
            guard let url = remoteAvatarURL(), let local = localAvatarURL() else { return }
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if !FileManager.default.fileExists(atPath: local.path) {
                    try data.write(to: local)
                }
            } catch {
                debugPrint("failed to download avatar from url: \(url), error: \(error)")
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
}
