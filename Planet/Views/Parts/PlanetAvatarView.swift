//
//  PlanetAvatarView.swift
//  Planet
//
//  Created by Kai on 2/19/23.
//

import SwiftUI
import CachedAsyncImage


struct PlanetAvatarView: View {
    var planet: Planet
    var size: CGSize = CGSize(width: 36, height: 36)
    
    @State private var planetAvatarURL: URL?

    var body: some View {
        planetAvatarView()
            .onReceive(NotificationCenter.default.publisher(for: .reloadPlanets)) { _ in
                Task(priority: .background) {
                    await MainActor.run {
                        planetAvatarURL = nil
                    }
                    await reloadAvatar()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .reloadPlanetAvatar(forID: planet.id))) { _ in
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
                    .cornerRadius(size.width * 0.5)
            } placeholder: {
                planetAvatarPlaceholder()
            }
            .frame(width: size.width)
        } else {
            planetAvatarPlaceholder()
        }
    }
    
    @ViewBuilder
    private func planetAvatarPlaceholder() -> some View {
        Image(systemName: "photo")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: size.width, height: size.width)
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

struct PlanetAvatarView_Previews: PreviewProvider {
    static var previews: some View {
        PlanetAvatarView(planet: .empty())
    }
}
