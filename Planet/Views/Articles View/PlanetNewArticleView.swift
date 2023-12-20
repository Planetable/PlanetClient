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
    @State private var choosePlanet: Bool = false
    @State private var isPreview: Bool = false
    @State private var previewPath: URL?
    @State private var shouldSaveAsDraft: Bool = false

    private let articleID: UUID
    var articleDraft: PlanetArticle?
    var newDraftMode: Bool = false

    init(withDraft draft: PlanetArticle?, draftMode: Bool) {
        if let draft {
            articleID = UUID(uuidString: draft.id)!
            articleDraft = draft
        } else {
            articleID = UUID()
            newDraftMode = draftMode
        }
    }

    var body: some View {
        NavigationStack {
            GeometryReader { g in
                VStack(spacing: 0) {
                    HStack(spacing: 12) {
                        if !newDraftMode {
                            Button(action: {
                                choosePlanet = true
                            }) {
                                if let planet = selectedPlanet {
                                    planet.avatarView(.medium)
                                }
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

                    Text(" ")
                        .frame(height: g.safeAreaInsets.bottom)
                        .frame(maxWidth: .infinity)
                        .background {
                            Color.secondary.opacity(0.15)
                        }
                }
                .frame(
                    minWidth: 0,
                    maxWidth: .infinity,
                    minHeight: 0,
                    maxHeight: .infinity,
                    alignment: .leading
                )
                .ignoresSafeArea(edges: .bottom)
            }
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
                                if let draft = articleDraft {
                                    let selectedAttachmentNames: [String] = selectedAttachments.map() { a in
                                        return a.url.lastPathComponent
                                    }
                                    if title != draft.title || content != draft.content || selectedAttachmentNames != draft.attachments {
                                        shouldSaveAsDraft.toggle()
                                        return
                                    }
                                } else {
                                    shouldSaveAsDraft.toggle()
                                    return
                                }
                            }
                            dismissAction()
                        } label: {
                            Image(systemName: "xmark")
                        }
                    }
                }
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button {
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
                        .disabled(appViewModel.myPlanets.count == 0)
                    }
                }
            }
            .task(priority: .utility) {
                if let draft = articleDraft {
                    self.restoreFromDraft(draft)
                } else {
                    if !newDraftMode {
                        self.selectedPlanet = self.appViewModel.myPlanets[self.selectedPlanetIndex]
                    }
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
            .sheet(isPresented: $choosePlanet) {
                PlanetPickerView(selectedPlanetIndex: $selectedPlanetIndex, selectedPlanet: $selectedPlanet)
                    .environmentObject(appViewModel)
            }
            .sheet(isPresented: $isPreview) {
                if let previewPath {
                    PlanetPreviewArticleView(url: previewPath)
                }
            }
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
        if articleDraft == nil {
            removeAttachments()
        }
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
