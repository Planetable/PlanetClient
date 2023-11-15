import SwiftUI


struct PlanetAvatarView: View {

    var planet: Planet
    var size: CGSize

    @State private var img: UIImage?

    private var imageCache: NSCache<NSString, UIImage>

    init(imageCache: NSCache<NSString, UIImage> = NSCache<NSString, UIImage>(), planet: Planet, size: CGSize, img: UIImage? = nil) {
        self.imageCache = imageCache
        self.planet = planet
        self.size = size
        self.img = img
    }

    var body: some View {
        let cacheKey = "\(size.width)x\(size.height)" as NSString
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
                            if let cachedImage = self.imageCache.object(forKey: cacheKey) {
                                await MainActor.run {
                                    self.img = cachedImage
                                }
                                return
                            }
                            let image = UIImage(contentsOfFile: avatarURL.path)
                            if let resized = image?.resizeToSquare(size: size) {
                                Task(priority: .background) {
                                    self.imageCache.setObject(resized, forKey: cacheKey)
                                }
                                await MainActor.run {
                                    self.img = resized
                                }
                            }
                        }
                        .controlSize(.small)
                }
            } else {
                planet.planetAvatarPlaceholder(size: size)
                    .task(priority: .background) {
                        await self.downloadAvatarFromRemote()
                    }
            }
        }
        .frame(width: size.width, height: size.height, alignment: .center)
        .onReceive(NotificationCenter.default.publisher(for: .reloadAvatar(byID: planet.id))) { _ in
            Task { @MainActor in
                self.img = nil
                self.imageCache.removeObject(forKey: cacheKey)
            }
        }
    }

    private func downloadAvatarFromRemote() async {
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
