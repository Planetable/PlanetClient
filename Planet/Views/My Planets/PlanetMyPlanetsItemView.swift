//
//  PlanetMyPlanetsItemView.swift
//  Planet
//
//  Created by Kai on 2/19/23.
//

import SwiftUI
import CachedAsyncImage


struct PlanetMyPlanetsItemView: View {
    var planet: Planet
    
    @State private var planetAvatarURL: URL?
    
    var body: some View {
        HStack(spacing: 12) {
            planetAvatarView()
            VStack {
                Text(planet.name)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(planet.about)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .foregroundColor(.secondary)
            }
            .multilineTextAlignment(.leading)
        }
        .contentShape(Rectangle())
        .frame(maxWidth: .infinity, minHeight: 48, idealHeight: 48, maxHeight: 96, alignment: .leading)
        .onReceive(NotificationCenter.default.publisher(for: .reloadPlanets)) { _ in
            Task(priority: .background) {
                await MainActor.run {
                    planetAvatarURL = nil
                }
                await reloadAvatar()
            }
        }
    }
    
    @ViewBuilder
    private func planetAvatarView() -> some View {
        if let planetAvatarURL {
            CachedAsyncImage(url: planetAvatarURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .cornerRadius(18)
            } placeholder: {
                planetAvatarPlaceholder()
            }
            .frame(width: 36)
        } else {
            planetAvatarPlaceholder()
        }
    }
    
    @ViewBuilder
    private func planetAvatarPlaceholder() -> some View {
        Image(systemName: "globe")
            .resizable()
            .frame(width: 36, height: 36)
            .cornerRadius(18)
    }
    
    private func reloadAvatar() async {
        let serverURL = PlanetSettingsViewModel.shared.serverURL
        if let url = URL(string: serverURL) {
            let baseAvatarURL = url.appendingPathComponent("/v0/planets/my/").appendingPathComponent(planet.id.uuidString).appendingPathComponent("/public")
            let pngAvatarURL = baseAvatarURL.appendingPathComponent("avatar.png")
            await MainActor.run {
                self.planetAvatarURL = pngAvatarURL
            }
        }
    }
}

struct PlanetMyPlanetsItemView_Previews: PreviewProvider {
    static var previews: some View {
        PlanetMyPlanetsItemView(planet: .empty())
    }
}
