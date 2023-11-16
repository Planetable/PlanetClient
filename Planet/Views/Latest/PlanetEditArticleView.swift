import SwiftUI

struct PlanetEditArticleView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var myPlanetsViewModel: PlanetMyPlanetsViewModel
    
    var planet: Planet
    var article: PlanetArticle
    
    @State private var title: String = ""
    @State private var content: String = ""
    @State private var attachments: [PlanetArticleAttachment] = []
    @State private var isPickerPresented: Bool = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    TextField("Title", text: $title)
                        .textFieldStyle(.plain)
                    Spacer(minLength: 1)
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
                
                Divider()
                    .padding(.vertical, 0)
                
                PlanetTextView(text: $content)
                    .padding(.horizontal, 12)
                
                PlanetAttachmentsView(planet: .constant(planet))
                    .frame(height: 48)
            }
            .frame(
                minWidth: 0,
                maxWidth: .infinity,
                minHeight: 0,
                maxHeight: .infinity,
                alignment: .leading
            )
            .navigationTitle("Edit Post")
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
                        Task(priority: .userInitiated) {
                            do {
                                try await PlanetManager.shared.modifyArticle(id: self.article.id, title: self.title, content: self.content, attachments: self.attachments, planetID: self.planet.id)
                                self.removeAttachments()
                            }
                            catch {
                                debugPrint("failed to save article: \(error)")
                            }
                        }
                    } label: {
                        Text("Save")
                    }
                    .disabled(title == "")
                }
            }
            .task(priority: .utility) {
                title = article.title
                content = article.content
                if let attachments = article.attachments {
                    for attachmentPath in attachments {
                        debugPrint("loading attachment: \(attachmentPath)")
                        guard let image = UIImage(contentsOfFile: attachmentPath) else { continue }
                        let attachment = PlanetArticleAttachment(id: UUID(), created: Date(), image: image, url: URL(filePath: attachmentPath))
                        Task { @MainActor in
                            self.attachments.append(attachment)
                        }
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .addAttachment)) { n in
                guard let attachment = n.object as? PlanetArticleAttachment else { return }
                if attachments.first(where: { $0.url == attachment.url }) == nil {
                    Task {
                        await MainActor.run {
                            debugPrint("added attachment: \(attachment.url)")
                            self.attachments.append(attachment)
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
    
    private func removeAttachments() {
        for attachment in attachments {
            try? FileManager.default.removeItem(at: attachment.url)
        }
    }
}
