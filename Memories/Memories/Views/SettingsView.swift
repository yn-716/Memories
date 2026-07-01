import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: MemoriesAppState
    @EnvironmentObject private var storeKitManager: StoreKitManager

    #if DEBUG
    @State private var showDebugResetAlert = false
    #endif
    @State private var showPurchase = false
    @State private var safariDestination: SettingsSupportDestination?
    @State private var settingsAlert: SettingsAlert?
    @State private var isRestoring = false

    var body: some View {
        let content = ZStack {
            MemoriesTheme.background.ignoresSafeArea()

            List {
                planSection
                languageSection
                privacySection
                storageSection
                supportPoliciesSection
                versionSection

                #if DEBUG
                debugSection
                #endif
            }
            .scrollContentBackground(.hidden)
            .frame(maxWidth: MemoriesLayoutMetrics.settingsMaxWidth)
        }
        .navigationTitle(appState.t("settings.title"))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPurchase) {
            PurchaseView()
        }
        .sheet(item: $safariDestination) { destination in
            SafariView(url: destination.url)
                .ignoresSafeArea()
        }
        .alert(item: $settingsAlert) { alert in
            Alert(
                title: Text(alert.title),
                message: alert.message.map(Text.init),
                dismissButton: .default(Text(appState.t("common.ok")))
            )
        }

        #if DEBUG
        content
        .alert(appState.t("settings.resetFreeDone"), isPresented: $showDebugResetAlert) {
            Button(appState.t("common.ok"), role: .cancel) {}
        }
        #else
        content
        #endif
    }

    private var planSection: some View {
        Section(appState.t("settings.plan")) {
            VStack(alignment: .leading, spacing: 8) {
                Text(planTitle)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(MemoriesTheme.textMain)

                Text(planSubtitle)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(MemoriesTheme.textSub)
            }
            .padding(.vertical, 4)

            Button(appState.t("settings.purchase")) {
                showPurchase = true
            }
            .foregroundStyle(MemoriesTheme.accentDeep)
            .lineLimit(1)
            .minimumScaleFactor(0.82)

            Button {
                Task {
                    await restorePurchases()
                }
            } label: {
                HStack {
                    Text(appState.t("settings.restore"))
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                    if isRestoring {
                        Spacer()
                        ProgressView()
                    }
                }
            }
            .foregroundStyle(MemoriesTheme.accentDeep)
            .disabled(isRestoring)
        }
    }

    private var languageSection: some View {
        Section(appState.t("settings.language")) {
            Picker(appState.t("settings.language"), selection: $appState.appLanguage) {
                ForEach(AppLanguage.allCases) { language in
                    Text(language.displayName(in: appState.resolvedLanguage))
                        .tag(language)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var privacySection: some View {
        Section(appState.t("settings.privacy")) {
            Toggle(isOn: $appState.suggestPlaceFromPhotoLocation) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(appState.t("settings.suggestPlaceFromPhotoLocation"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(MemoriesTheme.textMain)

                    Text(appState.t("settings.suggestPlaceFromPhotoLocationDescription"))
                        .font(.caption)
                        .foregroundStyle(MemoriesTheme.textSub)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 4)
            }
            .tint(MemoriesTheme.accentDeep)
        }
    }

    private var supportPoliciesSection: some View {
        Section(appState.t("settings.supportPolicies")) {
            ForEach(SettingsSupportDestination.allCases) { destination in
                Button {
                    safariDestination = destination
                } label: {
                    HStack(spacing: 12) {
                        Text(appState.t(destination.titleKey))
                            .foregroundStyle(MemoriesTheme.textMain)
                        Spacer(minLength: 12)
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(MemoriesTheme.textSub)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var storageSection: some View {
        Section(appState.t("settings.storage")) {
            Button {
                deleteTemporaryFiles()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "trash")
                        .foregroundStyle(MemoriesTheme.accentDeep)
                    Text(appState.t("settings.deleteTemporaryFiles"))
                        .foregroundStyle(MemoriesTheme.textMain)
                    Spacer()
                }
            }
            .buttonStyle(.plain)

            Text(appState.t("settings.deleteTemporaryFilesDescription"))
                .font(.caption)
                .foregroundStyle(MemoriesTheme.textSub)
        }
    }

    private var versionSection: some View {
        Section {
            HStack {
                Text(appState.t("settings.version"))
                Spacer()
                Text(Bundle.main.memoriesDisplayVersion)
                    .foregroundStyle(MemoriesTheme.textSub)
            }
        }
    }

    #if DEBUG
    private var debugSection: some View {
        Section(appState.t("settings.debug")) {
            VStack(alignment: .leading, spacing: 8) {
                Text(appState.t("settings.debugEntitlement"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(MemoriesTheme.textSub)

                Picker(appState.t("settings.debugEntitlement"), selection: $appState.debugEntitlementOverride) {
                    ForEach(DebugEntitlementOverride.allCases) { override in
                        Text(override.displayName(language: appState.resolvedLanguage))
                            .tag(override)
                    }
                }
                .pickerStyle(.menu)
            }
            .padding(.vertical, 4)

            VStack(alignment: .leading, spacing: 8) {
                Text(appState.t("settings.debugDraftLimit"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(MemoriesTheme.textSub)

                Picker(appState.t("settings.debugDraftLimit"), selection: $appState.debugDraftLimitOverride) {
                    ForEach(DebugDraftLimitOverride.allCases) { override in
                        Text(override.displayName(language: appState.resolvedLanguage))
                            .tag(override)
                    }
                }
                .pickerStyle(.menu)
            }
            .padding(.vertical, 4)

            VStack(alignment: .leading, spacing: 8) {
                Button(appState.t("settings.resetFree")) {
                    appState.resetDailyWatermarkFreeUseForDebug()
                    showDebugResetAlert = true
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(MemoriesTheme.accentDeep)

                Text(debugFreeExportStatusText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(MemoriesTheme.textMain)

                Text(appState.t("settings.resetFreeDescription"))
                    .font(.caption)
                    .foregroundStyle(MemoriesTheme.textSub)
            }
            .padding(.vertical, 4)
        }
    }
    #endif

    private var planTitle: String {
        let entitlement = appState.effectiveEntitlementState
        if entitlement.hasLifetimePass {
            return appState.t("settings.planLifetime")
        }

        if let expiry = entitlement.sevenDayPassExpiresAt, expiry > Date() {
            return appState.t("settings.planSevenDay")
        }

        return appState.t("settings.planFree")
    }

    private var planSubtitle: String {
        let entitlement = appState.effectiveEntitlementState
        if entitlement.hasLifetimePass {
            return appState.t("settings.canSaveWithout")
        }

        if let expiry = entitlement.sevenDayPassExpiresAt, expiry > Date() {
            return String(format: appState.t("settings.activeUntil"), appState.formattedDateTime(expiry))
        }

        let status = appState.watermarkPolicy().snapshot.remainingFreeExportsToday > 0
            ? appState.t("common.available")
            : appState.t("common.used")
        return String(format: appState.t("settings.todayFree"), status)
    }

    #if DEBUG
    private var debugFreeExportStatusText: String {
        let remaining = appState.watermarkPolicy().snapshot.remainingFreeExportsToday
        if remaining > 0 {
            return String(format: appState.t("settings.currentRemaining"), remaining)
        }

        return appState.t("settings.currentUsed")
    }
    #endif

    private func restorePurchases() async {
        isRestoring = true
        defer { isRestoring = false }

        let result = await storeKitManager.restorePurchases()
        switch result {
        case .restored:
            settingsAlert = SettingsAlert(title: appState.t("purchase.restored"), message: nil)
        case .noPurchases:
            settingsAlert = SettingsAlert(title: appState.t("purchase.noRestoredPurchases"), message: nil)
        case .failed(let error):
            settingsAlert = SettingsAlert(title: appState.t("purchase.restoreFailed"), message: error.localizedDescription)
        }
    }

    private func deleteTemporaryFiles() {
        do {
            _ = try MediaFileManager.shared.cleanupTemporaryFiles(olderThan: Date())
            settingsAlert = SettingsAlert(title: appState.t("settings.temporaryFilesDeleted"), message: nil)
        } catch {
            settingsAlert = SettingsAlert(title: appState.t("settings.temporaryFilesDeleteFailed"), message: error.localizedDescription)
        }
    }
}

private struct SettingsAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String?
}

private enum SettingsSupportDestination: String, CaseIterable, Identifiable {
    case support
    case privacy
    case legal

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .support:
            return "settings.supportPage"
        case .privacy:
            return "settings.privacyPolicy"
        case .legal:
            return "settings.legalDisclosure"
        }
    }

    var url: URL {
        switch self {
        case .support:
            return URL(string: "https://memories.myfs716.com/support/")!
        case .privacy:
            return URL(string: "https://memories.myfs716.com/privacy/")!
        case .legal:
            return URL(string: "https://memories.myfs716.com/legal/tokusho/")!
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
            .environmentObject(MemoriesAppState())
            .environmentObject(StoreKitManager())
            .environmentObject(AnnouncementStore())
    }
}
