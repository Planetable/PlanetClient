import SwiftUI
import PhotosUI


struct PlanetMyPlanetInfoView: View {
    @Environment(\.dismiss) private var dismiss

    var planet: Planet
    
    @State private var isEdit: Bool = false
    @State private var isDelete: Bool = false
    @State private var serverStatus: Bool = false

    @State private var planetName: String = ""
    @State private var planetAbout: String = ""
    @State private var planetAvatarPath: String = ""

    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedPhotoData: Data? {
        didSet {
            if let selectedPhotoData {
                let imageName = String(UUID().uuidString.prefix(4)) + ".png"
                let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(imageName)
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
        List {
            if isEdit {
                Section {
                    avatarEditView()
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

                Section {
                    Button(role: .destructive) {
                        isDelete.toggle()
                    } label: {
                        Text("Delete Planet")
                    }
                }
                .confirmationDialog("Delete Planet", isPresented: $isDelete) {
                    Button(role: .cancel) {
                    } label: {
                        Text("Cancel")
                    }
                    Button(role: .destructive) {
                        dismiss()
                        Task(priority: .userInitiated) {
                            do {
                                try await PlanetManager.shared.deletePlanet(id: self.planet.id)
                            } catch {
                                debugPrint("failed to update planet info: \(error)")
                            }
                        }
                    } label: {
                        Text("Delete Planet")
                    }
                } message: {
                    Text("Are you sure you want to delete \(planet.name)? This action cannot to undone.")
                }
            } else {
                Section {
                    if planetAvatarPath != "", let img = UIImage(contentsOfFile: planetAvatarPath) {
                        Image(uiImage: img)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: PlanetAvatarSize.large.size.width, height: PlanetAvatarSize.large.size.height, alignment: .center)
                            .clipShape(.circle)
                    } else {
                        planet.planetAvatarPlaceholder(size: PlanetAvatarSize.large.size)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

                Text(planetName)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(planetAbout == "" ? "No description" : planetAbout)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .foregroundColor(planet.about == "" ? .secondary : .primary)
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                if isEdit {
                    Button {
                        withAnimation {
                            isEdit.toggle()
                        }
                        planetName = planet.name
                        planetAbout = planet.about
                        if let avatarURL = planet.avatarURL, FileManager.default.fileExists(atPath: avatarURL.path) {
                            planetAvatarPath = avatarURL.path
                        } else {
                            planetAvatarPath = ""
                        }
                    } label: {
                        Text("Cancel")
                    }
                    Button {
                        Task(priority: .userInitiated) {
                            withAnimation {
                                self.isEdit.toggle()
                            }
                            do {
                                if let avatarURL = self.planet.avatarURL, FileManager.default.fileExists(atPath: avatarURL.path) {
                                    if avatarURL.path == self.planetAvatarPath {
                                        try await PlanetManager.shared.modifyPlanet(id: self.planet.id, name: self.planetName, about: self.planetAbout, avatarPath: "")
                                    } else {
                                        try await PlanetManager.shared.modifyPlanet(id: self.planet.id, name: self.planetName, about: self.planetAbout, avatarPath: self.planetAvatarPath)
                                    }
                                    self.planetAvatarPath = avatarURL.path
                                }
                            } catch {
                                debugPrint("failed to update planet info: \(error)")
                            }
                        }
                    } label: {
                        Text("Save")
                    }
                    .disabled(planetName == "" || !serverStatus)
                } else {
                    Button {
                        withAnimation {
                            isEdit.toggle()
                        }
                    } label: {
                        Text("Edit")
                    }
                    .disabled(planetName == "" || !serverStatus)
                }
            }
        }
        .task {
            planetName = planet.name
            planetAbout = planet.about
            if let avatarURL = planet.avatarURL, FileManager.default.fileExists(atPath: avatarURL.path) {
                planetAvatarPath = avatarURL.path
            }
            serverStatus = await PlanetSettingsViewModel.shared.serverIsOnline()
        }
    }

    @ViewBuilder
    private func avatarEditView() -> some View {
        VStack(spacing: 20) {
            Group {
                if let selectedPhotoData, let image = UIImage(data: selectedPhotoData) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: PlanetAvatarSize.large.size.width, height: PlanetAvatarSize.large.size.height, alignment: .center)
                        .clipShape(.circle)
                } else {
                    if planetAvatarPath != "", let img = UIImage(contentsOfFile: planetAvatarPath) {
                        Image(uiImage: img)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: PlanetAvatarSize.large.size.width, height: PlanetAvatarSize.large.size.height, alignment: .center)
                            .clipShape(.circle)
                    } else {
                        planet.planetAvatarPlaceholder(size: PlanetAvatarSize.large.size)
                    }
                }
            }

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
                    if let avatarURL = planet.avatarURL, FileManager.default.fileExists(atPath: avatarURL.path) {
                        planetAvatarPath = avatarURL.path
                    } else {
                        planetAvatarPath = ""
                    }
                } label: {
                    Text("Reset")
                }
                .buttonStyle(.plain)
            }
            .controlSize(.small)
        }
    }
}


struct PlanetMyPlanetInfoView_Previews: PreviewProvider {
    static var previews: some View {
        PlanetMyPlanetInfoView(planet: .empty())
    }
}
