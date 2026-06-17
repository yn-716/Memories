import SwiftUI
import UIKit

struct DraftsView: View {
    @State private var drafts: [DraftRecord] = []
    @State private var thumbnails: [UUID: UIImage] = [:]

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
        }
        .navigationTitle("下書き")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            reloadDrafts()
        }
    }

    private var header: some View {
        MemoriesGlassPanel {
            HStack {
                Text("下書き")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(MemoriesTheme.textMain)

                Spacer()

                Text("\(drafts.count)/\(DraftRepository.draftLimit)")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(MemoriesTheme.accentDeep)
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

                Text("下書きはまだありません")
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
                    NavigationLink {
                        draftDestination(for: draft)
                    } label: {
                        DraftRow(
                            draft: draft,
                            thumbnail: thumbnails[draft.id],
                            updatedText: Self.updatedFormatter.string(from: draft.updatedAt)
                        )
                    }
                    .buttonStyle(.plain)
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

    private static let updatedFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy.MM.dd HH:mm"
        return formatter
    }()
}

struct HistoryView: View {
    var body: some View {
        DraftsView()
    }
}

private struct DraftRow: View {
    let draft: DraftRecord
    let thumbnail: UIImage?
    let updatedText: String

    var body: some View {
        MemoriesGlassPanel {
            HStack(spacing: 12) {
                thumbnailView

                VStack(alignment: .leading, spacing: 6) {
                    Text(draft.title)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(MemoriesTheme.textMain)
                        .lineLimit(1)

                    Text(updatedText)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(MemoriesTheme.textSub)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(MemoriesTheme.textSub)
            }
            .padding(12)
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
    var body: some View {
        ZStack {
            MemoriesTheme.background.ignoresSafeArea()

            MemoriesGlassPanel {
                Text("下書き画像を読み込めませんでした")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(MemoriesTheme.textMain)
                    .frame(maxWidth: .infinity)
                    .padding(24)
            }
            .padding(24)
        }
        .navigationTitle("下書き")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        DraftsView()
    }
}
