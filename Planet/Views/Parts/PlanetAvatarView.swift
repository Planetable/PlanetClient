//
//  PlanetAvatarView.swift
//  Planet
//
//  Created by Kai on 2/19/23.
//

import SwiftUI

struct PlanetAvatarView: View {
    var planet: Planet
    var size: CGSize = CGSize(width: 36, height: 36)
    
    @State private var planetAvatarURL: URL?

    var body: some View {
        planetAvatarView()
            .onAppear {
                Task {
                    await loadAvatar()
                }
            }
    }
    
    @ViewBuilder
    private func planetAvatarView() -> some View {
        if let planetAvatarURL {
            AsyncImage(url: planetAvatarURL) { image in
                image
                    .interpolation(.high)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .cornerRadius(size.width * 0.5)
            } placeholder: {
                planetAvatarPlaceholder()
            }
            .frame(width: size.width)
            .overlay(
                RoundedRectangle(cornerRadius: size.width / 2)
                    .stroke(Color("BorderColor"), lineWidth: 0.5)
            )
            .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: 1)    
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
    
    private func loadAvatar() async {
        guard let localAvatarURL = localAvatarURL(for: planet) else {
            return
        }
        if FileManager.default.fileExists(atPath: localAvatarURL.path) {
            await MainActor.run {
                self.planetAvatarURL = localAvatarURL
            }
            return
        }
        await downloadAndStoreAvatar(from: remoteAvatarURL(for: planet), to: localAvatarURL)
    }
    
    private func localAvatarURL(for planet: Planet) -> URL? {
        guard let nodeID = PlanetAppViewModel.shared.currentNodeID,
              let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        let myPlanetPath = documentsDirectory.appendingPathComponent(nodeID).appendingPathComponent("My").appendingPathComponent(planet.id)
        do {
            try FileManager.default.createDirectory(at: myPlanetPath, withIntermediateDirectories: true)
        } catch {
            debugPrint("Failed to create directory for my planet: \(error)")
            return nil
        }
        return myPlanetPath.appendingPathComponent("avatar.png")
    }
    
    private func remoteAvatarURL(for planet: Planet) -> URL? {
        guard let serverURL = URL(string: PlanetSettingsViewModel.shared.serverURL) else {
            return nil
        }
        return serverURL
            .appendingPathComponent("/v0/planets/my/")
            .appendingPathComponent(planet.id)
            .appendingPathComponent("/public/avatar.png")
    }
    
    private func downloadAndStoreAvatar(from remoteURL: URL?, to localURL: URL) async {
        guard let remoteURL = remoteURL,
              let data = try? await Data(contentsOf: remoteURL) else {
            return
        }
        do {
            try data.write(to: localURL)
            debugPrint("Wrote avatar data to \(localURL)")
            await MainActor.run {
                self.planetAvatarURL = localURL
            }
        } catch {
            debugPrint("Failed to write avatar data to \(localURL): \(error)")
        }
    }
}

struct PlanetAvatarView_Previews: PreviewProvider {
    static var previews: some View {
        PlanetAvatarView(planet: .empty())
    }
}
