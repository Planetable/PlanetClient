import SwiftUI
import PhotosUI


struct PlanetNewPlanetView: View {
    @Environment(\.dismiss) private var dismiss
    
    @State private var serverStatus: Bool = false
    
    @State private var planetName: String = ""
    @State private var planetAbout: String = ""
    @State private var planetAvatarPath: String = ""
    
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedPhotoData: Data? {
        didSet {
            if let selectedPhotoData {
                let imageName = String(UUID().uuidString.prefix(4)) + ".png"
                let url = URL(fileURLWithPath: NSTemporaryDirectory()).appending(path: imageName)
                do {
                    if FileManager.default.fileExists(atPath: url.path) {
                        try FileManager.default.removeItem(at: url)
                    }
                    try selectedPhotoData.write(to: url)
                    planetAvatarPath = url.path
                } catch {
                    debugPrint("failed to save photo data: \(error)")
                }
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(spacing: 20) {
                        Group {
                            if let selectedPhotoData, let image = UIImage(data: selectedPhotoData) {
                                Image(uiImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } else {
                                if planetAvatarPath != "", let img = UIImage(contentsOfFile: planetAvatarPath) {
                                    Image(uiImage: img)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                } else {
                                    Image(systemName: "photo")
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                }
                            }
                        }
                        .frame(width: PlanetAvatarSize.large.size.width, height: PlanetAvatarSize.large.size.height, alignment: .center)
                        .clipShape(.circle)

                        HStack(spacing: 20) {
                            PhotosPicker(selection: $selectedItem, matching: .any(of: [.images, .not(.livePhotos)])) {
                                Text("Upload")
                            }
                            .onChange(of: selectedItem) { newValue in
                                Task(priority: .utility) {
                                    do {
                                        if let newValue, let data = try await newValue.loadTransferable(type: Data.self) {
                                            selectedPhotoData = data
                                        } else {
                                            selectedItem = nil
                                            selectedPhotoData = nil
                                        }
                                    } catch {
                                        selectedItem = nil
                                        selectedPhotoData = nil
                                    }
                                }
                            }
                            .buttonStyle(.bordered)

                            Button {
                                selectedItem = nil
                                selectedPhotoData = nil
                                planetAvatarPath = ""
                            } label: {
                                Text("Reset")
                            }
                            .buttonStyle(.plain)
                        }
                        .controlSize(.small)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

                TextField("Name", text: $planetName)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textFieldStyle(.plain)
                TextField("About", text: $planetAbout)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textFieldStyle(.plain)
            }
            .navigationTitle("New Planet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Text("Cancel")
                    }
                }
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                        Task(priority: .userInitiated) {
                            do {
                                try await PlanetManager.shared.createPlanet(name: planetName, about: planetAbout, avatarPath: planetAvatarPath)
                                Task { @MainActor in
                                    PlanetAppViewModel.shared.selectedTab = .myPlanets
                                }
                            } catch {
                                debugPrint("failed to create planet: \(error)")
                            }
                        }
                    } label: {
                        Text("Create")
                    }
                    .disabled(planetName == "" || !serverStatus)
                }
            }
            .task(priority: .background) {
                let status = await PlanetSettingsViewModel.shared.serverIsOnline()
                await MainActor.run {
                    self.serverStatus = status
                }
            }
        }
    }
}
