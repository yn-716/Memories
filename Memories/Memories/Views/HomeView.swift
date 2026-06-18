import PhotosUI
import SwiftUI
import UIKit

struct HomeView: View {
    private let template = TemplateRepository.bundled.loadTemplates().templates.first ?? .previewPetLifelog

    @EnvironmentObject private var appState: MemoriesAppState
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var editorRoute: EditorRoute?
    @State private var isLoadingPhoto = false
    @State private var photoErrorMessage: String?
    @State private var showPurchase = false
    @State private var showPhotoPicker = false
    @State private var showDraftFullBeforeEdit = false
    @State private var showDrafts = false

    var body: some View {
        let photoButtonTitle = isLoadingPhoto ? appState.t("common.loading") : appState.t("home.choosePhoto")

        NavigationStack {
            ZStack {
                MemoriesTheme.background.ignoresSafeArea()

                VStack(alignment: .leading, spacing: 26) {
                    Spacer(minLength: 24)

                    hero

                    MemoriesGlassPanel {
                        VStack(spacing: 14) {
                            Button {
                                startPhotoSelection()
                            } label: {
                                MemoriesPrimaryButtonLabel(
                                    title: photoButtonTitle,
                                    systemImage: "photo"
                                )
                            }
                            .buttonStyle(.plain)
                            .photosPicker(
                                isPresented: $showPhotoPicker,
                                selection: $selectedPhotoItem,
                                matching: .images,
                                photoLibrary: .shared()
                            )
                            .disabled(isLoadingPhoto)

                            NavigationLink {
                                DraftsView()
                            } label: {
                                HomeActionRow(title: appState.t("home.drafts"), systemImage: "tray")
                            }

                            NavigationLink {
                                SettingsView()
                            } label: {
                                HomeActionRow(title: appState.t("home.settings"), systemImage: "gearshape")
                            }
                        }
                        .padding(18)
                    }

                    Button {
                        showPurchase = true
                    } label: {
                        PurchaseEntryButton()
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity, alignment: .trailing)

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
                .frame(maxWidth: MemoriesLayoutMetrics.homeMaxWidth, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(isPresented: $showDrafts) {
                DraftsView()
            }
            .navigationDestination(item: $editorRoute) { route in
                EditorView(template: route.template, photoImage: route.photoImage)
            }
            .task(id: selectedPhotoItem) {
                await loadSelectedPhoto()
            }
            .sheet(isPresented: $showPurchase) {
                PurchaseView()
            }
            .alert(appState.t("drafts.full.title"), isPresented: $showDraftFullBeforeEdit) {
                Button(appState.t("drafts.manage")) {
                    showDrafts = true
                }

                Button(appState.t("editor.continue")) {
                    showPhotoPicker = true
                }

                Button(appState.t("common.cancel"), role: .cancel) {}
            } message: {
                Text(appState.t("drafts.fullBeforeEdit.message"))
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

            Text(appState.t("home.tagline"))
                .font(.headline.weight(.medium))
                .foregroundStyle(MemoriesTheme.textSub)
                .lineSpacing(3)
        }
    }

    @MainActor
    private func startPhotoSelection() {
        if DraftRepository.shared.loadDrafts().count >= appState.draftLimit {
            showDraftFullBeforeEdit = true
        } else {
            showPhotoPicker = true
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
                photoErrorMessage = appState.t("home.photoLoadFailed")
                return
            }

            editorRoute = EditorRoute(template: template, photoImage: image)
        } catch {
            photoErrorMessage = appState.t("home.photoLoadError")
        }
    }
}

private struct PurchaseEntryButton: View {
    @EnvironmentObject private var appState: MemoriesAppState

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: "sparkles")
                .font(.caption.weight(.semibold))
                .foregroundStyle(MemoriesTheme.accentDeep)

            Text(appState.t("purchase.entry.title"))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(MemoriesTheme.accentDeep)
                .lineLimit(1)
                .minimumScaleFactor(0.86)
                .layoutPriority(1)
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(MemoriesTheme.border.opacity(0.72), lineWidth: 1)
        }
        .fixedSize(horizontal: true, vertical: false)
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
        .environmentObject(MemoriesAppState())
}
