import SwiftUI
import PhotosUI

struct PlanetMyPlanetInfoView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appViewModel: PlanetAppViewModel

    var planet: Planet

    @State private var isEdit: Bool = false
    @State private var isDelete: Bool = false
    @State private var serverStatus: Bool = false

    @State private var planetName: String = ""
    @State private var planetAbout: String = ""
    @State private var planetTemplateName: String = ""
    @State private var planetAvatarPath: String = ""

    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedPhotoData: Data? {
        didSet {
            if let selectedPhotoData {
                let imageName = String(UUID().uuidString.prefix(4)) + ".png"
                let url = URL.cachesDirectory.appending(path: imageName)
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

                Section {
                    TextField("Name", text: $planetName)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textFieldStyle(.plain)
                } header: {
                    Text("Name")
                }
                .textCase(.none)

                Section {
                    TextField("About", text: $planetAbout)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textFieldStyle(.plain)
                } header: {
                    Text("Description")
                }
                .textCase(.none)

                Section {
                    Picker("Templates", selection: $planetTemplateName) {
                        ForEach(PlanetManager.shared.templates, id: \.self) { t in
                            Text(t.name)
                                .tag(t.name)
                        }
                    }
                } header: {
                    Text("Templates")
                }
                .textCase(.none)

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

                Section {
                    Text(planetName)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } header: {
                    Text("Name")
                }
                .textCase(.none)

                Section {
                    Text(planetAbout == "" ? "No description" : planetAbout)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .foregroundColor(planet.about == "" ? .secondary : .primary)
                } header: {
                    Text("Description")
                }
                .textCase(.none)

                Section {
                    Text(planetTemplateName)
                } header: {
                    Text("Templates")
                }
                .textCase(.none)

                let latest: [PlanetArticle] = appViewModel.myArticles.filter({ $0.planetID?.uuidString == planet.id })
                if latest.count > 0 {
                    Section {
                        ForEach(latest, id: \.id) { article in
                            NavigationLink {
                                PlanetArticleView(planet: planet, article: article)
                            } label: {
                                PlanetLatestItemView(planet: planet, article: article, showAvatar: false)
                            }
                        }
                    } header: {
                        Text("Latest")
                    }
                    .textCase(.none)
                }
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
                        planetTemplateName = planet.templateName
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
                                        try await PlanetManager.shared.modifyPlanet(id: self.planet.id, name: self.planetName, about: self.planetAbout, templateName: self.planetTemplateName, avatarPath: "")
                                    } else {
                                        try await PlanetManager.shared.modifyPlanet(id: self.planet.id, name: self.planetName, about: self.planetAbout, templateName: self.planetTemplateName, avatarPath: self.planetAvatarPath)
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
        .task(priority: .utility) {
            planetName = planet.name
            planetAbout = planet.about
            planetTemplateName = planet.templateName
            if let avatarURL = planet.avatarURL, FileManager.default.fileExists(atPath: avatarURL.path) {
                planetAvatarPath = avatarURL.path
            }
            serverStatus = await PlanetStatus.shared.serverIsOnline()
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
                    // MARK: TODO: delete avatar image.
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
