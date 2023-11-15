//
//  PlanetNewArticleView.swift
//  Planet
//
//  Created by Kai on 2/20/23.
//

import SwiftUI

struct PlanetNewArticleView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var myPlanetsViewModel: PlanetMyPlanetsViewModel

    @State private var selectedPlanetIndex: Int = 0
    @State private var selectedPlanet: Planet?
    @State private var selectedAttachments: [PlanetArticleAttachment] = []
    @State private var title: String = ""
    @State private var content: String = ""
    @State private var isPickerPresented: Bool = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Button(action: {
                        isPickerPresented = true
                    }) {
                        if let planet = selectedPlanet {
                            planet.avatarView(.medium)
                        }
                    }
                    .sheet(isPresented: $isPickerPresented) {
                        NavigationView {
                            List {
                                ForEach(myPlanetsViewModel.myPlanets.indices, id: \.self) {
                                    index in
                                    let planet = myPlanetsViewModel.myPlanets[index]
                                    planet.listItemView(showCheckmark: selectedPlanetIndex == index)
                                        .onTapGesture {
                                            selectedPlanetIndex = index
                                            selectedPlanet = planet
                                            debugPrint("selected planet: \(planet)")
                                            isPickerPresented = false  // Assuming you want to dismiss the view on selection
                                        }
                                }
                            }
                            .navigationTitle("Select a Planet")
                            .toolbar {
                                ToolbarItem(placement: .confirmationAction) {
                                    Button("Done") {
                                        isPickerPresented = false
                                    }
                                }
                            }
                            .disabled(myPlanetsViewModel.myPlanets.count == 0)
                        }
                    }

                    TextField("Title", text: $title)
                        .textFieldStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)

                Divider()
                    .padding(.vertical, 0)

                PlanetTextView(text: $content)
                    .padding(.horizontal, 12)

                PlanetAttachmentsView(planet: $selectedPlanet)
                    .frame(height: 48)
            }
            .frame(
                minWidth: 0,
                maxWidth: .infinity,
                minHeight: 0,
                maxHeight: .infinity,
                alignment: .leading
            )
            .navigationTitle("New Post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                        removeAttachments()
                    } label: {
                        Text("Cancel")
                    }
                }
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                        guard let selectedPlanet else { return }
                        Task(priority: .userInitiated) {
                            do {
                                debugPrint(
                                    "Clicked save button: \(title), \(content), \(selectedAttachments.count), \(selectedPlanet.name)"
                                )
                                try await PlanetManager.shared.createArticle(
                                    title: self.title,
                                    content: self.content,
                                    attachments: self.selectedAttachments,
                                    forPlanet: selectedPlanet
                                )
                                self.removeAttachments()
                            }
                            catch {
                                debugPrint("failed to save article: \(error)")
                            }
                        }
                    } label: {
                        Text("Send")
                    }
                    .disabled(title == "" || myPlanetsViewModel.myPlanets.count == 0)
                }
            }
            .task(priority: .utility) {
                do {
                    try await refreshAction()
                    self.selectedPlanet =
                        self.myPlanetsViewModel.myPlanets[self.selectedPlanetIndex]
                }
                catch {
                    debugPrint("failed to refresh: \(error)")
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .addAttachment)) { n in
                guard let attachment = n.object as? PlanetArticleAttachment else { return }
                if selectedAttachments.first(where: { $0.url == attachment.url }) == nil {
                    Task {
                        await MainActor.run {
                            debugPrint("added attachment: \(attachment.url)")
                            self.selectedAttachments.append(attachment)
                        }
                    }
                }
                Task {
                    await MainActor.run {
                        NotificationCenter.default.post(name: .insertAttachment, object: attachment)
                    }
                }
            }
        }
    }

    private func refreshAction() async throws {
        let planets = try await PlanetManager.shared.getMyPlanets()
        await MainActor.run {
            self.myPlanetsViewModel.updateMyPlanets(planets)
        }
    }

    private func removeAttachments() {
        for attachment in selectedAttachments {
            try? FileManager.default.removeItem(at: attachment.url)
        }
    }
}

struct PlanetNewArticleView_Previews: PreviewProvider {
    static var previews: some View {
        PlanetNewArticleView()
    }
}
