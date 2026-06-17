import PhotosUI
import SwiftUI
import UIKit

struct HomeView: View {
    private let template = TemplateRepository.bundled.loadTemplates().templates.first ?? .previewPetLifelog

    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var editorRoute: EditorRoute?
    @State private var isLoadingPhoto = false
    @State private var photoErrorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                MemoriesTheme.background.ignoresSafeArea()

                VStack(alignment: .leading, spacing: 26) {
                    Spacer(minLength: 24)

                    hero

                    MemoriesGlassPanel {
                        VStack(spacing: 14) {
                            PhotosPicker(
                                selection: $selectedPhotoItem,
                                matching: .images,
                                photoLibrary: .shared()
                            ) {
                                MemoriesPrimaryButtonLabel(
                                    title: isLoadingPhoto ? "読み込み中..." : "写真を選ぶ",
                                    systemImage: "photo"
                                )
                            }
                            .disabled(isLoadingPhoto)

                            NavigationLink {
                                DraftsView()
                            } label: {
                                HomeActionRow(title: "下書き", systemImage: "tray")
                            }

                            NavigationLink {
                                SettingsView()
                            } label: {
                                HomeActionRow(title: "設定", systemImage: "gearshape")
                            }
                        }
                        .padding(18)
                    }

                    if let photoErrorMessage {
                        Text(photoErrorMessage)
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(MemoriesTheme.textSub)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(MemoriesTheme.subBackground.opacity(0.75))
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }

                    Spacer()
                }
                .padding(24)
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(item: $editorRoute) { route in
                EditorView(template: route.template, photoImage: route.photoImage)
            }
            .task(id: selectedPhotoItem) {
                await loadSelectedPhoto()
            }
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: "pawprint.fill")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(MemoriesTheme.accentDeep)
                    .frame(width: 44, height: 44)
                    .background(MemoriesTheme.subBackground.opacity(0.86))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                Text("Memories")
                    .font(.largeTitle.weight(.semibold))
                    .foregroundStyle(MemoriesTheme.textMain)
            }

            Text("うちの子の今日を、おしゃれな1枚に")
                .font(.headline.weight(.medium))
                .foregroundStyle(MemoriesTheme.textSub)
                .lineSpacing(3)
        }
    }

    @MainActor
    private func loadSelectedPhoto() async {
        guard let selectedPhotoItem else {
            return
        }

        isLoadingPhoto = true
        photoErrorMessage = nil
        defer {
            isLoadingPhoto = false
            self.selectedPhotoItem = nil
        }

        do {
            guard
                let data = try await selectedPhotoItem.loadTransferable(type: Data.self),
                let image = UIImage(data: data)
            else {
                photoErrorMessage = "写真を読み込めませんでした。別の写真でもう一度お試しください。"
                return
            }

            editorRoute = EditorRoute(template: template, photoImage: image)
        } catch {
            photoErrorMessage = "写真の読み込みに失敗しました。時間をおいてもう一度お試しください。"
        }
    }
}

private struct EditorRoute: Identifiable, Hashable {
    let id = UUID()
    let template: Template
    let photoImage: UIImage

    static func == (lhs: EditorRoute, rhs: EditorRoute) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

private struct HomeActionRow: View {
    let title: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(MemoriesTheme.accentDeep)
                .frame(width: 32, height: 32)
                .background(MemoriesTheme.subBackground.opacity(0.82))
                .clipShape(Circle())

            Text(title)
                .font(.headline.weight(.semibold))
                .foregroundStyle(MemoriesTheme.textMain)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(MemoriesTheme.textSub)
        }
        .padding(14)
        .background(MemoriesTheme.card.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(MemoriesTheme.border.opacity(0.65), lineWidth: 1)
        }
    }
}

#Preview {
    HomeView()
}
