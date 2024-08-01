import SwiftUI

private class PlanetAvatarCacheManager: NSObject {
    static let shared = PlanetAvatarCacheManager()

    private var avatarCache: NSCache<NSString, UIImage>

    override init() {
        avatarCache = NSCache<NSString, UIImage>()
        avatarCache.totalCostLimit = 20 * 1024 * 1024
        super.init()
    }

    func getAvatar(byPlanetID id: String, andSize size: CGSize) -> UIImage? {
        let key = cacheKey(byID: id, andSize: size)
        return avatarCache.object(forKey: key)
    }

    func setAvatar(_ image: UIImage, forPlanetID id: String, andSize size: CGSize) {
        let key = cacheKey(byID: id, andSize: size)
        avatarCache.setObject(image, forKey: key)
    }

    func removeAvatar(byPlanetID id: String, andSize size: CGSize) {
        let key = cacheKey(byID: id, andSize: size)
        avatarCache.removeObject(forKey: key)
    }

    private func cacheKey(byID id: String, andSize size: CGSize) -> NSString {
        return ("\(id)-\(size.width)x\(size.height)" as NSString)
    }
}

struct PlanetAvatarView: View {

    var planet: Planet
    var size: CGSize

    @State private var img: UIImage?

    init(planet: Planet, size: CGSize) {
        self.planet = planet
        self.size = size
        if let image = PlanetAvatarCacheManager.shared.getAvatar(
            byPlanetID: planet.id,
            andSize: size
        ) {
            self.img = image
        }
    }

    var body: some View {
        Group {
            if let avatarURL = planet.avatarURL,
                FileManager.default.fileExists(atPath: avatarURL.path),
                let data = try? Data(contentsOf: avatarURL), data.count > 1 {
                if let img {
                    Image(uiImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: size.width, height: size.height, alignment: .center)
                        .clipShape(.circle)
                        .overlay(
                            RoundedRectangle(cornerRadius: size.width / 2)
                                .stroke(Color("BorderColor"), lineWidth: 0.5)
                        )
                        .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: 1)
                } else {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .task(priority: .utility) {
                            if let cachedImage = PlanetAvatarCacheManager.shared.getAvatar(
                                byPlanetID: self.planet.id,
                                andSize: self.size
                            ) {
                                await MainActor.run {
                                    self.img = cachedImage
                                }
                                return
                            }
                            let image = UIImage(contentsOfFile: avatarURL.path)
                            if let resized = image?.resizeToSquare(size: size) {
                                Task(priority: .background) {
                                    PlanetAvatarCacheManager.shared.setAvatar(
                                        resized,
                                        forPlanetID: self.planet.id,
                                        andSize: self.size
                                    )
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
                PlanetAvatarCacheManager.shared.removeAvatar(
                    byPlanetID: self.planet.id,
                    andSize: self.size
                )
                self.img = nil
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
        let myPlanetPath =
            documentsDirectory
            .appending(path: nodeID)
            .appending(path: "My")
            .appending(path: planet.id)
        guard let serverURL = URL(string: PlanetAppViewModel.shared.currentServerURLString) else {
            return
        }
        let remoteAvatarURL =
            serverURL
//            .appending(path: "/v0/planets/my/")
            .appending(path: planet.id)
            .appending(path: "avatar.png")
        let localAvatarURL = myPlanetPath.appending(path: "avatar.png")
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
