//
//  PlanetNewArticleView.swift
//  Planet
//
//  Created by Kai on 2/20/23.
//

import SwiftUI

struct PlanetNewArticleView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appViewModel: PlanetAppViewModel

    @State private var selectedPlanetIndex: Int = UserDefaults.standard.integer(forKey: .selectedPlanetIndex) {
        didSet {
            UserDefaults.standard.setValue(selectedPlanetIndex, forKey: .selectedPlanetIndex)
        }
    }
    @State private var selectedPlanet: Planet?
    @State private var selectedAttachments: [PlanetArticleAttachment] = []
    @State private var title: String = ""
    @State private var content: String = ""
    @State private var isPickerPresented: Bool = false
    @State private var isPreview: Bool = false
    @State private var previewPath: URL?
    @State private var shouldSaveAsDraft: Bool = false

    private let articleID: UUID
    var articleDraft: PlanetArticle?

    init(withDraft draft: PlanetArticle?) {
        if let draft {
            articleID = UUID(uuidString: draft.id)!
            articleDraft = draft
        } else {
            articleID = UUID()
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if isPreview, let previewPath {
                    PlanetArticleWebView(url: previewPath)
                        .ignoresSafeArea(edges: .bottom)
                } else {
                    HStack(spacing: 12) {
                        Button(action: {
                            isPickerPresented = true
                        }) {
                            if let planet = selectedPlanet {
                                planet.avatarView(.medium)
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

                    Group {
                        if let draft = articleDraft {
                            PlanetAttachmentsView(planet: $selectedPlanet, articleDraft: draft)
                        } else {
                            PlanetAttachmentsView(planet: $selectedPlanet)
                        }
                    }
                    .frame(height: 48)
                }
            }
            .frame(
                minWidth: 0,
                maxWidth: .infinity,
                minHeight: 0,
                maxHeight: .infinity,
                alignment: .leading
            )
            .navigationTitle(isPreview ? "Preview" :"New Post")
            .navigationBarTitleDisplayMode(.inline)
            .alert(isPresented: $shouldSaveAsDraft) {
                Alert(
                    title: Text("Save as Draft?"),
                    primaryButton: .default(Text("Save")) {
                        saveAsDraftAction()
                        dismissAction()
                    },
                    secondaryButton: .cancel(Text("Discard")) {
                        dismissAction()
                    }
                )
            }
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarLeading) {
                    if !isPreview {
                        Button {
                            if title.count > 0 || content.count > 0 || selectedAttachments.count > 0 {
                                shouldSaveAsDraft.toggle()
                            } else {
                                dismissAction()
                            }
                        } label: {
                            Image(systemName: "xmark")
                        }
                    }
                }
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button {
                        withAnimation {
                            self.isPreview.toggle()
                            Task(priority: .userInitiated) {
                                if self.isPreview {
                                    do {
                                        let url = try PlanetManager.shared.renderArticlePreview(forTitle: self.title, content: self.content, andArticleID: self.articleID.uuidString)
                                        Task { @MainActor in
                                            self.previewPath = url
                                        }
                                    } catch {
                                        debugPrint("failed to render preview: \(error)")
                                    }
                                }
                            }
                        }
                    } label: {
                        Image(systemName: isPreview ? "xmark" : "eye.fill")
                    }
                    .disabled(title == "" && content == "")
                    if !isPreview {
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
                                    Task { @MainActor in
                                        self.appViewModel.selectedTab = .latest
                                        if let articleDraft {
                                            self.appViewModel.removeDraft(articleDraft)
                                        }
                                    }
                                }
                                catch {
                                    debugPrint("failed to save article: \(error)")
                                }
                            }
                        } label: {
                            Image(systemName: "paperplane.fill")
                        }
                        .disabled(title == "" || appViewModel.myPlanets.count == 0)
                    }
                }
            }
            .task(priority: .utility) {
                if let draft = articleDraft {
                    self.restoreFromDraft(draft)
                } else {
                    self.selectedPlanet = self.appViewModel.myPlanets[self.selectedPlanetIndex]
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
            .sheet(isPresented: $isPickerPresented) {
                planetPickerView()
            }
        }
    }
    
    @ViewBuilder
    private func planetPickerView() -> some View {
        NavigationView {
            List {
                ForEach(appViewModel.myPlanets.indices, id: \.self) {
                    index in
                    let planet = appViewModel.myPlanets[index]
                    planet.listItemView(showCheckmark: selectedPlanetIndex == index)
                        .onTapGesture {
                            selectedPlanetIndex = index
                            selectedPlanet = planet
                            debugPrint("selected planet: \(planet)")
                            isPickerPresented = false  // Assuming you want to dismiss the view on selection
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                NotificationCenter.default.post(name: .reloadAvatar(byID: planet.id), object: nil)
                            }
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
            .disabled(appViewModel.myPlanets.count == 0)
        }
    }

    private func saveAsDraftAction() {
        do {
            _ = try PlanetManager.shared.renderArticlePreview(forTitle: title, content: content, andArticleID: articleID.uuidString)
            let attachments = selectedAttachments.map() { a in
                return a.url.lastPathComponent
            }
            var planetID: UUID?
            if let selectedPlanet, let theID = UUID(uuidString: selectedPlanet.id) {
                planetID = theID
            }
            try PlanetManager.shared.saveArticleDraft(byID: articleID, attachments: attachments, title: title, content: content, planetID: planetID)
        } catch {
            debugPrint("failed to save draft: \(error)")
        }
    }

    private func dismissAction() {
        dismiss()
        removeAttachments()
    }

    private func removeAttachments() {
        for attachment in selectedAttachments {
            try? FileManager.default.removeItem(at: attachment.url)
        }
    }

    private func restoreFromDraft(_ draft: PlanetArticle) {
        title = draft.title ?? ""
        content = draft.content ?? ""
        if let planetID = draft.planetID, let planet = Planet.getPlanet(forID: planetID.uuidString) {
            selectedPlanet = planet
            var index: Int = 0
            for myPlanet in PlanetAppViewModel.shared.myPlanets {
                if myPlanet.id == planetID.uuidString {
                    selectedPlanetIndex = index
                }
                index += 1
            }
            let articleDraftPath = PlanetManager.shared.draftsDirectory.appending(path: draft.id)
            if let attachments = draft.attachments {
                for attachment in attachments {
                    let attachmentPath = articleDraftPath.appending(path: attachment)
                    if let image = UIImage(contentsOfFile: attachmentPath.path) {
                        let articleAttachment = PlanetArticleAttachment(id: UUID(), created: Date(), image: image, url: attachmentPath)
                        selectedAttachments.append(articleAttachment)
                    }
                }
            }
        }
    }
}
