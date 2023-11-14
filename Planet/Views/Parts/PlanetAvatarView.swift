import SwiftUI


struct PlanetAvatarView: View {
    var planet: Planet
    var size: CGSize

    @State private var img: UIImage?

    var body: some View {
        Group {
            if let avatarURL = planet.avatarURL, FileManager.default.fileExists(atPath: avatarURL.path) {
                if let img {
                    Image(uiImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: size.width, height: size.height, alignment: .center)
                        .clipShape(.circle)
                } else {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .task(priority: .background) {
                            // MARK: TODO: Cache resized avatar image till next planet modification
                            let image = UIImage(contentsOfFile: avatarURL.path)
                            await MainActor.run {
                                self.img = image
                            }
                        }
                        .controlSize(.small)
                }
            } else {
                planet.planetAvatarPlaceholder(size: size)
                    .task(priority: .background) {
                        guard let nodeID = PlanetAppViewModel.shared.currentNodeID,
                            let documentsDirectory = FileManager.default.urls(
                                for: .documentDirectory,
                                in: .userDomainMask
                            ).first
                        else {
                            return
                        }
                        let myPlanetPath = documentsDirectory
                            .appendingPathComponent(nodeID)
                            .appendingPathComponent("My")
                            .appendingPathComponent(planet.id)
                        guard let serverURL = URL(string: PlanetSettingsViewModel.shared.serverURL) else {
                            return
                        }
                        let remoteAvatarURL = serverURL
                            .appendingPathComponent("/v0/planets/my/")
                            .appendingPathComponent(planet.id)
                            .appendingPathComponent("/public/avatar.png")
                        let localAvatarURL = myPlanetPath.appendingPathComponent("avatar.png")
                        guard !FileManager.default.fileExists(atPath: localAvatarURL.path) else {
                            return
                        }
                        do {
                            let (data, _) = try await URLSession.shared.data(from: remoteAvatarURL)
                            if !FileManager.default.fileExists(atPath: localAvatarURL.path) {
                                try data.write(to: localAvatarURL)
                            }
                        } catch {
                            debugPrint("failed to download avatar from url: \(remoteAvatarURL), error: \(error)")
                        }
                    }
            }
        }
        .frame(width: size.width, height: size.height, alignment: .center)
        .onReceive(NotificationCenter.default.publisher(for: .reloadAvatar(byID: planet.id))) { _ in
            Task { @MainActor in
                self.img = nil
            }
        }
    }
}
