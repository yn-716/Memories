import StoreKit
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: MemoriesAppState

    #if DEBUG
    @State private var showDebugResetAlert = false
    #endif
    @State private var showPurchase = false
    @State private var settingsAlert: SettingsAlert?
    @State private var isRestoring = false

    var body: some View {
        let content = ZStack {
            MemoriesTheme.background.ignoresSafeArea()

            List {
                planSection
                languageSection
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
        // TODO: StoreKit商品ID確定後、購入状態の起動時同期をPhase 2で強化する。
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

    private var versionSection: some View {
        Section {
            HStack {
                Text(appState.t("settings.version"))
                Spacer()
                Text("1.0")
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

        do {
            try await AppStore.sync()
            await appState.applyCurrentEntitlements()
            settingsAlert = SettingsAlert(title: appState.t("purchase.restored"), message: nil)
        } catch {
            settingsAlert = SettingsAlert(title: appState.t("purchase.restoreFailed"), message: error.localizedDescription)
        }
    }
}

private struct SettingsAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String?
}

#Preview {
    NavigationStack {
        SettingsView()
            .environmentObject(MemoriesAppState())
    }
}
