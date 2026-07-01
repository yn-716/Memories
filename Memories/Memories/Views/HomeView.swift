import PhotosUI
import SwiftUI
import UIKit

struct HomeView: View {
    private let templates = TemplateRepository.bundled.loadTemplates().templates

    @EnvironmentObject private var appState: MemoriesAppState
    @EnvironmentObject private var announcementStore: AnnouncementStore
    @State private var selectedMediaItem: PhotosPickerItem?
    @State private var editorRoute: EditorRoute?
    @State private var isLoadingMedia = false
    @State private var mediaErrorMessage: String?
    @State private var showPurchase = false
    @State private var showPhotoPicker = false
    @State private var showStyleSelection = false
    @State private var selectedCreationStyle: CardCreationStyle = .ticketFrame
    @State private var showDraftFullBeforeEdit = false
    @State private var showDrafts = false
    @State private var showPetCalendar = false
    @State private var showPetCalendarToday = false
    @State private var showAnnouncements = false

    var body: some View {
        let mediaButtonTitle = isLoadingMedia ? appState.t("common.loading") : appState.t("home.imageEditor")

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
                                    title: mediaButtonTitle,
                                    systemImage: "photo"
                                )
                            }
                            .buttonStyle(.plain)
                            .photosPicker(
                                isPresented: $showPhotoPicker,
                                selection: $selectedMediaItem,
                                matching: .any(of: [.images, .videos]),
                                photoLibrary: .shared()
                            )
                            .disabled(isLoadingMedia)

                            Button {
                                showPetCalendar = true
                            } label: {
                                MemoriesPrimaryButtonLabel(
                                    title: appState.t("home.petCalendar"),
                                    systemImage: "calendar",
                                    gradientColors: [
                                        Color(hex: "#5E927F").opacity(0.96),
                                        Color(hex: "#9AD3BF").opacity(0.86)
                                    ],
                                    shadowColor: Color(hex: "#5E927F").opacity(0.13)
                                )
                            }
                            .buttonStyle(.plain)

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

                    if let mediaErrorMessage {
                        Text(mediaErrorMessage)
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
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    AnnouncementBellButton(unreadCount: announcementStore.unreadCount()) {
                        showAnnouncements = true
                    }
                }
            }
            .navigationDestination(isPresented: $showDrafts) {
                DraftsView()
            }
            .navigationDestination(isPresented: $showPetCalendar) {
                PetCalendarHomeView()
            }
            .navigationDestination(isPresented: $showPetCalendarToday) {
                PetCalendarHomeView(openTodayEditorOnAppear: true)
            }
            .navigationDestination(isPresented: $showAnnouncements) {
                AnnouncementsView()
            }
            .navigationDestination(item: $editorRoute) { route in
                EditorView(
                    template: route.template,
                    media: route.media,
                    initialEditState: route.initialEditState
                )
            }
            .task(id: selectedMediaItem) {
                await loadSelectedMedia()
            }
            .sheet(isPresented: $showPurchase) {
                PurchaseView()
            }
            .sheet(isPresented: $showStyleSelection) {
                StyleSelectionView { style in
                    selectedCreationStyle = style
                    showStyleSelection = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                        showPhotoPicker = true
                    }
                }
            }
            .alert(appState.t("drafts.full.title"), isPresented: $showDraftFullBeforeEdit) {
                Button(appState.t("drafts.manage")) {
                    showDrafts = true
                }

                Button(appState.t("editor.continue")) {
                    showStyleSelection = true
                }

                Button(appState.t("common.cancel"), role: .cancel) {}
            } message: {
                Text(appState.t("drafts.fullBeforeEdit.message"))
            }
            .onOpenURL { url in
                handleDeepLink(url)
            }
            .task {
                _ = try? MediaFileManager.shared.cleanupTemporaryFiles()
                DraftRepository.shared.cleanupOrphanedFiles()
                await announcementStore.refreshIfNeeded()
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

                Text(appState.t("app.name"))
                    .font(.largeTitle.weight(.semibold))
                    .foregroundStyle(MemoriesTheme.textMain)
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 8)
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
            showStyleSelection = true
        }
    }

    @MainActor
    private func loadSelectedMedia() async {
        guard let selectedMediaItem else {
            return
        }

        isLoadingMedia = true
        mediaErrorMessage = nil
        defer {
            isLoadingMedia = false
            self.selectedMediaItem = nil
        }

        do {
            let media = try await EditableMediaLoader().load(
                from: selectedMediaItem,
                allowsLocationSuggestion: appState.suggestPlaceFromPhotoLocation
            )
            let template = template(for: selectedCreationStyle, media: media)
            let initialEditState = initialEditState(from: media, template: template)
            editorRoute = EditorRoute(
                template: template,
                media: media,
                initialEditState: initialEditState
            )
        } catch {
            mediaErrorMessage = appState.t("home.mediaLoadError")
        }
    }

    private func initialEditState(from media: EditableMedia, template: Template) -> CardEditState {
        var state = CardEditState.newCard(
            defaultLayout: template.defaultLayout,
            fontRole: template.overlayStyle.defaultFontRole,
            textColor: template.overlayStyle.defaultTextColor,
            date: media.capturedAt ?? Date()
        )

        if template.renderStyle.isRetroFilm {
            state.visibilitySettings = VisibilitySettings(
                showThemeIcon: false,
                showLocation: false,
                showDate: true,
                showWeather: false,
                showMainText: false,
                showSubText: false
            )
            state.selectedWeather = .none
            state.retroFilterType = .sepia
            return state
        }

        if let locationText = media.locationText?.trimmingCharacters(in: .whitespacesAndNewlines), !locationText.isEmpty {
            state.locationText = String(locationText.prefix(30))
            state.visibilitySettings.showLocation = true
        }

        return state
    }

    private func template(for style: CardCreationStyle, media: EditableMedia) -> Template {
        switch style {
        case .ticketFrame:
            let aspectRatio = media.contentSize.width / max(media.contentSize.height, 1)
            let renderStyle: TemplateRenderStyle = aspectRatio >= 1.15 ? .ticketLandscape : .ticketPortrait
            return templates.first(where: { $0.renderStyle == renderStyle })
                ?? templates.first(where: { $0.renderStyle.isTicket })
                ?? simpleTemplate
        case .simpleCard:
            return simpleTemplate
        case .retroFilm:
            return templates.first(where: { $0.renderStyle == .retroFilm }) ?? simpleTemplate
        }
    }

    private var simpleTemplate: Template {
        templates.first(where: { $0.renderStyle == .simpleCard }) ?? .previewPetLifelog
    }

    private func handleDeepLink(_ url: URL) {
        switch MemoriesDeepLinkRouter.route(for: url) {
        case .petCalendar:
            showPetCalendar = true
        case .petCalendarToday:
            showPetCalendarToday = true
        case nil:
            break
        }
    }
}

private enum CardCreationStyle: CaseIterable, Identifiable {
    case ticketFrame
    case simpleCard
    case retroFilm

    var id: Self { self }

    func title(language: ResolvedAppLanguage) -> String {
        switch self {
        case .ticketFrame:
            return MemoriesLocalization.text("style.ticketFrame", language: language)
        case .simpleCard:
            return MemoriesLocalization.text("style.simpleCard", language: language)
        case .retroFilm:
            return MemoriesLocalization.text("style.retroFilm", language: language)
        }
    }

    func description(language: ResolvedAppLanguage) -> String {
        switch self {
        case .ticketFrame:
            return MemoriesLocalization.text("style.ticketFrameDescription", language: language)
        case .simpleCard:
            return MemoriesLocalization.text("style.simpleCardDescription", language: language)
        case .retroFilm:
            return MemoriesLocalization.text("style.retroFilmDescription", language: language)
        }
    }

    var systemImage: String {
        switch self {
        case .ticketFrame:
            return "ticket"
        case .simpleCard:
            return "photo.on.rectangle"
        case .retroFilm:
            return "film"
        }
    }
}

private struct StyleSelectionView: View {
    let onSelect: (CardCreationStyle) -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: MemoriesAppState

    var body: some View {
        NavigationStack {
            ZStack {
                MemoriesTheme.background.ignoresSafeArea()

                VStack(alignment: .leading, spacing: 16) {
                    VStack(spacing: 12) {
                        ForEach(CardCreationStyle.allCases) { style in
                            Button {
                                onSelect(style)
                            } label: {
                                StyleSelectionRow(style: style)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(22)
                .frame(maxWidth: MemoriesLayoutMetrics.sheetMaxWidth, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(appState.t("common.cancel")) {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.height(360), .medium])
        .presentationDragIndicator(.visible)
    }
}

private struct StyleSelectionRow: View {
    let style: CardCreationStyle

    @EnvironmentObject private var appState: MemoriesAppState

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: style.systemImage)
                .font(.headline.weight(.semibold))
                .foregroundStyle(MemoriesTheme.accentDeep)
                .frame(width: 42, height: 42)
                .background(MemoriesTheme.subBackground.opacity(0.72))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 5) {
                Text(style.title(language: appState.resolvedLanguage))
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(MemoriesTheme.textMain)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Text(style.description(language: appState.resolvedLanguage))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(MemoriesTheme.textSub)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(MemoriesTheme.textSub)
        }
        .padding(15)
        .background(.ultraThinMaterial)
        .background(MemoriesTheme.card.opacity(0.54))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(MemoriesTheme.border.opacity(0.72), lineWidth: 1)
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
    let media: EditableMedia
    let initialEditState: CardEditState

    static func == (lhs: EditorRoute, rhs: EditorRoute) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

struct HomeActionRow: View {
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
        .environmentObject(StoreKitManager())
        .environmentObject(AnnouncementStore())
}
