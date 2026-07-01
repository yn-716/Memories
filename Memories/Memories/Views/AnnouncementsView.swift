import SwiftUI

struct AnnouncementBellButton: View {
    let unreadCount: Int
    let action: () -> Void

    @EnvironmentObject private var appState: MemoriesAppState

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "bell")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(MemoriesTheme.accentDeep)
                    .frame(width: 42, height: 42)

                if unreadCount > 0 {
                    Text(unreadCount > 99 ? "99+" : "\(unreadCount)")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .padding(.horizontal, 5)
                        .frame(minWidth: 18, minHeight: 18)
                        .background(Color.red.opacity(0.92))
                        .clipShape(Capsule())
                        .offset(x: 5, y: -5)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(appState.t("home.announcements"))
    }
}

struct AnnouncementsView: View {
    @EnvironmentObject private var appState: MemoriesAppState
    @EnvironmentObject private var announcementStore: AnnouncementStore
    @State private var safariURL: AnnouncementURL?

    var body: some View {
        ZStack {
            MemoriesTheme.background.ignoresSafeArea()

            VStack(spacing: 14) {
                header

                if announcementStore.visibleAnnouncements().isEmpty {
                    emptyState
                } else {
                    announcementList
                }
            }
            .padding(20)
            .frame(maxWidth: MemoriesLayoutMetrics.settingsMaxWidth)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .navigationTitle(appState.t("announcements.title"))
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await announcementStore.refreshIfNeeded()
        }
        .sheet(item: $safariURL) { destination in
            SafariView(url: destination.url)
                .ignoresSafeArea()
        }
    }

    private var header: some View {
        MemoriesGlassPanel {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Text(appState.t("announcements.title"))
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(MemoriesTheme.textMain)

                    Spacer()

                    if announcementStore.isLoading {
                        ProgressView()
                            .tint(MemoriesTheme.accentDeep)
                    }
                }

                if announcementStore.loadFailed {
                    Text(appState.t("announcements.loadFailed"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(MemoriesTheme.textSub)
                }

                HStack(spacing: 10) {
                    MemoriesSecondaryButton(appState.t("announcements.refresh"), systemImage: "arrow.clockwise") {
                        Task {
                            await announcementStore.refresh(force: true)
                        }
                    }
                    .disabled(announcementStore.isLoading)

                    MemoriesSecondaryButton(appState.t("announcements.markAllRead"), systemImage: "checkmark.circle") {
                        announcementStore.markAllRead()
                    }
                    .disabled(announcementStore.unreadCount() == 0)
                }
            }
            .padding(14)
        }
    }

    private var emptyState: some View {
        MemoriesGlassPanel {
            VStack(spacing: 12) {
                Image(systemName: "bell")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(MemoriesTheme.accentDeep)
                    .frame(width: 48, height: 48)
                    .background(MemoriesTheme.subBackground.opacity(0.82))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                Text(appState.t("announcements.empty"))
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(MemoriesTheme.textMain)
            }
            .frame(maxWidth: .infinity)
            .padding(24)
        }
    }

    private var announcementList: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(announcementStore.visibleAnnouncements()) { announcement in
                    NavigationLink {
                        AnnouncementDetailView(announcement: announcement) { url in
                            safariURL = AnnouncementURL(url: url)
                        }
                    } label: {
                        AnnouncementRow(
                            announcement: announcement,
                            isUnread: announcementStore.isUnread(announcement)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
    }
}

private struct AnnouncementRow: View {
    let announcement: Announcement
    let isUnread: Bool

    @EnvironmentObject private var appState: MemoriesAppState

    var body: some View {
        MemoriesGlassPanel {
            HStack(spacing: 12) {
                Circle()
                    .fill(isUnread ? MemoriesTheme.accentDeep : MemoriesTheme.border.opacity(0.65))
                    .frame(width: 10, height: 10)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(announcement.title(language: appState.resolvedLanguage))
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(MemoriesTheme.textMain)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)

                        if isUnread {
                            Text(appState.t("announcements.unread"))
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(MemoriesTheme.accentDeep.opacity(0.88))
                                .clipShape(Capsule())
                        }
                    }

                    Text(announcement.body(language: appState.resolvedLanguage))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(MemoriesTheme.textSub)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(MemoriesTheme.textSub)
            }
            .padding(14)
        }
    }
}

struct AnnouncementDetailView: View {
    let announcement: Announcement
    let onOpenURL: (URL) -> Void

    @EnvironmentObject private var appState: MemoriesAppState
    @EnvironmentObject private var announcementStore: AnnouncementStore

    var body: some View {
        ZStack {
            MemoriesTheme.background.ignoresSafeArea()

            ScrollView {
                MemoriesGlassPanel {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(announcement.title(language: appState.resolvedLanguage))
                            .font(.title3.weight(.bold))
                            .foregroundStyle(MemoriesTheme.textMain)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(announcement.body(language: appState.resolvedLanguage))
                            .font(.body.weight(.medium))
                            .foregroundStyle(MemoriesTheme.textSub)
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)

                        if let url = announcement.url {
                            MemoriesPrimaryButton(appState.t("announcements.openURL"), systemImage: "safari") {
                                onOpenURL(url)
                            }
                        }
                    }
                    .padding(18)
                }
                .padding(20)
                .frame(maxWidth: MemoriesLayoutMetrics.settingsMaxWidth)
                .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle(appState.t("announcements.title"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            announcementStore.markRead(announcement)
        }
    }
}

private struct AnnouncementURL: Identifiable {
    let id = UUID()
    let url: URL
}
