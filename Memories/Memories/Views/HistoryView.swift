import SwiftUI
import UIKit

struct DraftsView: View {
    @EnvironmentObject private var appState: MemoriesAppState

    @State private var drafts: [DraftRecord] = []
    @State private var thumbnails: [UUID: UIImage] = [:]
    @State private var pendingDeletion: DraftRecord?

    private let repository = DraftRepository.shared
    private let templates = TemplateRepository.bundled.loadTemplates().templates

    var body: some View {
        ZStack {
            MemoriesTheme.background.ignoresSafeArea()

            VStack(spacing: 14) {
                header

                if drafts.isEmpty {
                    emptyState
                } else {
                    draftList
                }
            }
            .padding(20)
            .frame(maxWidth: MemoriesLayoutMetrics.draftsMaxWidth)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle(appState.t("drafts.title"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            reloadDrafts()
        }
        .alert(appState.t("drafts.deleteQuestion"), isPresented: deleteConfirmationBinding) {
            Button(appState.t("drafts.delete"), role: .destructive) {
                deletePendingDraft()
            }

            Button(appState.t("common.cancel"), role: .cancel) {
                pendingDeletion = nil
            }
        }
    }

    private var header: some View {
        MemoriesGlassPanel {
            HStack {
                Text(appState.t("drafts.title"))
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(MemoriesTheme.textMain)

                Spacer()

                Text("\(drafts.count)/\(appState.draftLimit)")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(MemoriesTheme.accentDeep)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
            .padding(16)
        }
    }

    private var emptyState: some View {
        MemoriesGlassPanel {
            VStack(spacing: 12) {
                Image(systemName: "tray")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(MemoriesTheme.accentDeep)
                    .frame(width: 48, height: 48)
                    .background(MemoriesTheme.subBackground.opacity(0.82))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                Text(appState.t("drafts.empty"))
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(MemoriesTheme.textMain)
            }
            .frame(maxWidth: .infinity)
            .padding(24)
        }
    }

    private var draftList: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(drafts) { draft in
                    MemoriesGlassPanel {
                        HStack(spacing: 10) {
                            NavigationLink {
                                draftDestination(for: draft)
                            } label: {
                                DraftRow(
                                    draft: draft,
                                    thumbnail: thumbnails[draft.id],
                                    title: draftDisplayTitle(for: draft),
                                    updatedText: appState.formattedDateTime(draft.updatedAt)
                                )
                            }
                            .buttonStyle(.plain)

                            Button {
                                pendingDeletion = draft
                            } label: {
                                Image(systemName: "trash")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.red.opacity(0.78))
                                    .frame(width: 40, height: 40)
                                    .background(MemoriesTheme.card.opacity(0.46))
                                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                                            .stroke(MemoriesTheme.border.opacity(0.62), lineWidth: 1)
                                    }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(appState.t("drafts.delete"))
                        }
                        .padding(12)
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }

    @ViewBuilder
    private func draftDestination(for draft: DraftRecord) -> some View {
        let template = templates.first(where: { $0.id == draft.templateID }) ?? .previewPetLifelog

        if let image = repository.image(for: draft) {
            EditorView(
                template: template,
                photoImage: image,
                initialEditState: draft.editState,
                draftID: draft.id
            )
        } else {
            MissingDraftImageView()
        }
    }

    private func reloadDrafts() {
        drafts = repository.loadDrafts()
        thumbnails = Dictionary(
            uniqueKeysWithValues: drafts.compactMap { draft in
                guard let thumbnail = repository.thumbnail(for: draft) else {
                    return nil
                }
                return (draft.id, thumbnail)
            }
        )
    }

    private var deleteConfirmationBinding: Binding<Bool> {
        Binding(
            get: { pendingDeletion != nil },
            set: { isPresented in
                if !isPresented {
                    pendingDeletion = nil
                }
            }
        )
    }

    private func draftDisplayTitle(for draft: DraftRecord) -> String {
        let trimmed = draft.editState.mainText.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? appState.t("drafts.untitled") : trimmed
    }

    private func deletePendingDraft() {
        guard let pendingDeletion else {
            return
        }

        try? repository.deleteDraft(id: pendingDeletion.id)
        self.pendingDeletion = nil
        reloadDrafts()
    }
}

struct HistoryView: View {
    var body: some View {
        DraftsView()
    }
}

private struct DraftRow: View {
    let draft: DraftRecord
    let thumbnail: UIImage?
    let title: String
    let updatedText: String

    var body: some View {
        HStack(spacing: 12) {
            thumbnailView

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(MemoriesTheme.textMain)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                Text(updatedText)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(MemoriesTheme.textSub)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(MemoriesTheme.textSub)
        }
    }

    @ViewBuilder
    private var thumbnailView: some View {
        if let thumbnail {
            Image(uiImage: thumbnail)
                .resizable()
                .scaledToFill()
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(MemoriesTheme.border.opacity(0.7), lineWidth: 1)
                }
        } else {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(MemoriesTheme.subBackground.opacity(0.86))
                .frame(width: 64, height: 64)
                .overlay {
                    Image(systemName: "photo")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(MemoriesTheme.accentDeep)
                }
        }
    }
}

private struct MissingDraftImageView: View {
    @EnvironmentObject private var appState: MemoriesAppState

    var body: some View {
        ZStack {
            MemoriesTheme.background.ignoresSafeArea()

            MemoriesGlassPanel {
                Text(appState.t("drafts.missingImage"))
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(MemoriesTheme.textMain)
                    .frame(maxWidth: .infinity)
                    .padding(24)
            }
            .padding(24)
        }
        .navigationTitle(appState.t("drafts.title"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        DraftsView()
            .environmentObject(MemoriesAppState())
    }
}
