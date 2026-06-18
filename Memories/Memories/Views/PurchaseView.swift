import StoreKit
import SwiftUI

struct PurchaseView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: MemoriesAppState

    @State private var products: [String: Product] = [:]
    @State private var isLoading = false
    @State private var isProcessing = false
    @State private var productsLoadFailed = false
    @State private var alert: PurchaseAlert?

    var body: some View {
        NavigationStack {
            ZStack {
                MemoriesTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        currentStatusCard

                        if productsLoadFailed {
                            productLoadErrorCard
                        }

                        if !isLifetimePlan {
                            productCard(for: .sevenDayPass)
                        }
                        productCard(for: .lifetimePass)

                        MemoriesSecondaryButton(appState.t("purchase.restore"), systemImage: "arrow.clockwise") {
                            Task {
                                await restorePurchases()
                            }
                        }
                        .disabled(isProcessing)
                    }
                    .padding(22)
                    .frame(maxWidth: MemoriesLayoutMetrics.purchaseMaxWidth, alignment: .leading)
                    .frame(maxWidth: .infinity)
                }

                if isLoading || isProcessing {
                    ProgressView(appState.t("preview.processing"))
                        .font(.subheadline.weight(.semibold))
                        .tint(MemoriesTheme.accentDeep)
                        .padding(18)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
            .navigationTitle(appState.t("purchase.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(appState.t("common.close")) {
                        dismiss()
                    }
                }
            }
            .task {
                await loadProducts()
            }
            .alert(item: $alert) { alert in
                Alert(
                    title: Text(alert.title),
                    message: alert.message.map(Text.init),
                    dismissButton: .default(Text(appState.t("common.ok")))
                )
            }
        }
    }

    private var currentStatusCard: some View {
        MemoriesGlassPanel {
            HStack(spacing: 12) {
                Image(systemName: currentStatusIconName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(MemoriesTheme.accentDeep)
                    .frame(width: 34, height: 34)
                    .background(MemoriesTheme.subBackground.opacity(0.82))
                    .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(currentPlanTitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(MemoriesTheme.textMain)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)

                    Text(currentPlanSubtitle)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(MemoriesTheme.textSub)
                        .lineLimit(2)
                        .minimumScaleFactor(0.78)
                }

                Spacer(minLength: 0)
            }
            .padding(14)
        }
    }

    private var productLoadErrorCard: some View {
        MemoriesGlassPanel {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(MemoriesTheme.accentDeep)
                    .frame(width: 34, height: 34)
                    .background(MemoriesTheme.subBackground.opacity(0.82))
                    .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(appState.t("purchase.productsFailed"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(MemoriesTheme.textMain)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)

                    Text(appState.t("purchase.tryAgainLater"))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(MemoriesTheme.textSub)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)
            }
            .padding(14)
        }
    }

    private func productCard(for productID: PurchaseProductID) -> some View {
        let product = products[productID.rawValue]
        let state = productState(for: productID)
        let canPurchase = canStartPurchase(productID, state: state)

        return MemoriesGlassPanel {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: productID == .sevenDayPass ? "calendar.badge.clock" : "infinity")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(MemoriesTheme.accentDeep)
                        .frame(width: 42, height: 42)
                        .background(MemoriesTheme.subBackground.opacity(0.82))
                        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))

                    VStack(alignment: .leading, spacing: 5) {
                        Text(title(for: productID))
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(MemoriesTheme.textMain)
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)

                        Text(state.productSubtitle)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(state.canPurchase ? MemoriesTheme.textMain : MemoriesTheme.accentDeep)
                            .lineLimit(2)
                            .minimumScaleFactor(0.82)

                        if !detail(for: productID).isEmpty {
                            Text(detail(for: productID))
                                .font(.caption.weight(.medium))
                                .foregroundStyle(MemoriesTheme.textSub)
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    Spacer(minLength: 0)
                }

                HStack {
                    if state.showsPrice {
                        Text(product?.displayPrice ?? appState.t("purchase.unavailable"))
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(product == nil ? MemoriesTheme.textSub : MemoriesTheme.accentDeep)
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)
                    }

                    Spacer()

                    Button {
                        Task {
                            await purchase(productID)
                        }
                    } label: {
                        Text(state.buttonTitle)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)
                            .foregroundStyle(canPurchase ? .white : MemoriesTheme.textSub)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 10)
                            .background(canPurchase ? MemoriesTheme.accentDeep.opacity(0.9) : MemoriesTheme.subBackground.opacity(0.72))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(MemoriesTheme.border.opacity(canPurchase ? 0.2 : 0.72), lineWidth: 1)
                            }
                    }
                    .buttonStyle(.plain)
                    .disabled(!canPurchase)
                }
            }
            .padding(18)
        }
    }

    private func title(for productID: PurchaseProductID) -> String {
        switch productID {
        case .sevenDayPass:
            return appState.t("purchase.sevenDay.title")
        case .lifetimePass:
            return appState.t("purchase.lifetime.title")
        }
    }

    private func subtitle(for productID: PurchaseProductID) -> String {
        switch productID {
        case .sevenDayPass:
            return appState.t("purchase.sevenDay.subtitle")
        case .lifetimePass:
            return appState.t("purchase.lifetime.subtitle")
        }
    }

    private func detail(for productID: PurchaseProductID) -> String {
        switch productID {
        case .sevenDayPass:
            return appState.t("purchase.sevenDay.detail")
        case .lifetimePass:
            return appState.t("purchase.lifetime.detail")
        }
    }

    private var currentStatusIconName: String {
        switch currentPlanState {
        case .free:
            return "seal"
        case .sevenDay:
            return "calendar.badge.clock"
        case .lifetime:
            return "checkmark.seal"
        }
    }

    private var currentPlanTitle: String {
        switch currentPlanState {
        case .free:
            return appState.t("purchase.currentPlan.free")
        case .sevenDay:
            return appState.t("purchase.currentPlan.sevenDay")
        case .lifetime:
            return appState.t("purchase.currentPlan.lifetime")
        }
    }

    private var currentPlanSubtitle: String {
        switch currentPlanState {
        case .free:
            let status = appState.watermarkPolicy().snapshot.remainingFreeExportsToday > 0
                ? appState.t("common.available")
                : appState.t("common.used")
            return String(format: appState.t("purchase.todayStatus"), status)
        case .sevenDay(let expiry):
            return remainingText(until: expiry)
        case .lifetime:
            return appState.t("purchase.noWatermarkAvailable")
        }
    }

    private var currentPlanState: PurchasePlanState {
        let entitlement = appState.effectiveEntitlementState
        if entitlement.hasLifetimePass {
            return .lifetime
        }

        if let expiry = entitlement.sevenDayPassExpiresAt, expiry > Date() {
            return .sevenDay(expiry)
        }

        return .free
    }

    private var isLifetimePlan: Bool {
        if case .lifetime = currentPlanState {
            return true
        }

        return false
    }

    private func productState(for productID: PurchaseProductID) -> PurchaseProductState {
        switch currentPlanState {
        case .free:
            return PurchaseProductState(
                productSubtitle: subtitle(for: productID),
                buttonTitle: appState.t("purchase.purchase"),
                canPurchase: true,
                showsPrice: true
            )
        case .sevenDay:
            if productID == .sevenDayPass {
                return PurchaseProductState(
                    productSubtitle: appState.t("purchase.active"),
                    buttonTitle: appState.t("purchase.active"),
                    canPurchase: false,
                    showsPrice: false
                )
            }

            return PurchaseProductState(
                productSubtitle: subtitle(for: productID),
                buttonTitle: appState.t("purchase.purchase"),
                canPurchase: true,
                showsPrice: true
            )
        case .lifetime:
            return PurchaseProductState(
                productSubtitle: appState.t("purchase.purchased"),
                buttonTitle: appState.t("purchase.purchased"),
                canPurchase: false,
                showsPrice: false
            )
        }
    }

    private func canStartPurchase(_ productID: PurchaseProductID, state: PurchaseProductState) -> Bool {
        guard state.canPurchase, !isProcessing else {
            return false
        }

        if products[productID.rawValue] != nil {
            return true
        }

        #if DEBUG
        // Local debug builds often do not have StoreKit products configured.
        // Keep the plan rule testable: a 7-Day Pass must not block Lifetime.
        return !isLoading
        #else
        return false
        #endif
    }

    private func remainingText(until expiry: Date) -> String {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let expiryDay = calendar.startOfDay(for: expiry)
        let days = calendar.dateComponents([.day], from: today, to: expiryDay).day ?? 0

        if days <= 0 {
            return appState.t("purchase.endsToday")
        }

        if days == 1 {
            return appState.t("purchase.remainingOneDay")
        }

        return String(format: appState.t("purchase.remainingDays"), days)
    }

    private func loadProducts() async {
        guard products.isEmpty else {
            return
        }

        isLoading = true
        productsLoadFailed = false
        defer { isLoading = false }

        do {
            let storeProducts = try await Product.products(for: PurchaseProductID.allStoreProductIDs)
            var mappedProducts: [String: Product] = [:]
            for product in storeProducts {
                guard let productID = PurchaseProductID.matching(productID: product.id) else {
                    continue
                }

                mappedProducts[productID.rawValue] = mappedProducts[productID.rawValue] ?? product
            }

            products = mappedProducts
            productsLoadFailed = products.count < PurchaseProductID.allCases.count
        } catch {
            productsLoadFailed = true
            alert = PurchaseAlert(title: appState.t("purchase.productsFailed"), message: error.localizedDescription)
        }
    }

    private func purchase(_ productID: PurchaseProductID) async {
        guard let product = products[productID.rawValue] else {
            #if DEBUG
            appState.applyPurchasedProduct(id: productID.rawValue)
            alert = PurchaseAlert(title: appState.t("purchase.completed"), message: nil)
            return
            #else
            alert = PurchaseAlert(title: appState.t("purchase.productsFailed"), message: nil)
            return
            #endif
        }

        isProcessing = true
        defer { isProcessing = false }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                guard case .verified(let transaction) = verification else {
                    alert = PurchaseAlert(title: appState.t("purchase.failed"), message: nil)
                    return
                }

                appState.applyPurchasedProduct(id: transaction.productID)
                await transaction.finish()
                alert = PurchaseAlert(title: appState.t("purchase.completed"), message: nil)
            case .userCancelled, .pending:
                break
            @unknown default:
                break
            }
        } catch {
            alert = PurchaseAlert(title: appState.t("purchase.failed"), message: error.localizedDescription)
        }
    }

    private func restorePurchases() async {
        isProcessing = true
        defer { isProcessing = false }

        do {
            try await AppStore.sync()
            await appState.applyCurrentEntitlements()
            alert = PurchaseAlert(title: appState.t("purchase.restored"), message: nil)
        } catch {
            alert = PurchaseAlert(title: appState.t("purchase.restoreFailed"), message: error.localizedDescription)
        }
    }
}

private enum PurchasePlanState {
    case free
    case sevenDay(Date)
    case lifetime
}

private struct PurchaseProductState {
    let productSubtitle: String
    let buttonTitle: String
    let canPurchase: Bool
    let showsPrice: Bool
}

private struct PurchaseAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String?
}

#Preview {
    PurchaseView()
        .environmentObject(MemoriesAppState())
}
