import Foundation
import Combine
import StoreKit

@MainActor
final class StoreKitManager: ObservableObject {
    @Published private(set) var products: [PurchaseProductID: Product] = [:]
    @Published private(set) var isLoadingProducts = false
    @Published private(set) var isProcessingPurchase = false
    @Published private(set) var isRestoringPurchases = false
    @Published private(set) var productsLoadFailed = false
    @Published private(set) var purchaseError: Error?
    @Published private(set) var developmentPriceLabels: [PurchaseProductID: String] = [:]

    private weak var appState: MemoriesAppState?
    private var hasConfigured = false
    private var transactionUpdatesTask: Task<Void, Never>?

    deinit {
        transactionUpdatesTask?.cancel()
    }

    func configure(appState: MemoriesAppState) {
        self.appState = appState

        guard !hasConfigured else {
            return
        }

        hasConfigured = true
        startTransactionUpdates()

        Task {
            await refreshCurrentEntitlements()
        }
    }

    func productDisplayPrice(for productID: PurchaseProductID) -> String? {
        if let displayPrice = products[productID]?.displayPrice {
            return displayPrice
        }

        #if DEBUG
        return developmentPriceLabels[productID]
        #else
        return nil
        #endif
    }

    func hasStoreProduct(for productID: PurchaseProductID) -> Bool {
        products[productID] != nil
    }

    func loadProducts(forceReload: Bool = false) async {
        if isLoadingProducts {
            return
        }

        if !forceReload, !products.isEmpty {
            return
        }

        isLoadingProducts = true
        productsLoadFailed = false
        purchaseError = nil
        defer { isLoadingProducts = false }

        do {
            logStoreKitEnvironmentIfNeeded()
            storeKitDebugLog("Loading products: \(PurchaseProductID.allStoreProductIDs.joined(separator: ", "))")
            let storeProducts = try await Product.products(for: PurchaseProductID.allStoreProductIDs)
            storeKitDebugLog("StoreKit returned \(storeProducts.count) product(s): \(storeProducts.map(\.id).joined(separator: ", "))")
            var loadedProducts: [PurchaseProductID: Product] = [:]

            for product in storeProducts {
                guard let productID = PurchaseProductID.matching(productID: product.id) else {
                    continue
                }

                loadedProducts[productID] = product
            }

            products = loadedProducts
            refreshDevelopmentPriceLabelsIfNeeded(loadedProducts: loadedProducts)
            productsLoadFailed = loadedProducts.count < PurchaseProductID.allCases.count
            if productsLoadFailed {
                let missingIDs = PurchaseProductID.allCases
                    .filter { loadedProducts[$0] == nil }
                    .map(\.rawValue)
                    .joined(separator: ", ")
                storeKitDebugLog("Missing products: \(missingIDs)")
            }
            storeKitDebugLog("Loaded products: \(loadedProducts.keys.map(\.rawValue).joined(separator: ", "))")
        } catch {
            products = [:]
            refreshDevelopmentPriceLabelsIfNeeded(loadedProducts: [:])
            productsLoadFailed = true
            purchaseError = error
            storeKitDebugLog("Product load failed: \(error.localizedDescription)")
        }
    }

    func purchase(_ productID: PurchaseProductID) async -> StorePurchaseResult {
        guard let product = products[productID] else {
            return .productsUnavailable
        }

        isProcessingPurchase = true
        purchaseError = nil
        defer { isProcessingPurchase = false }

        do {
            storeKitDebugLog("Purchase started: \(productID.rawValue)")
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                guard PurchaseProductID.matching(productID: transaction.productID) != nil else {
                    await transaction.finish()
                    return .failed(StoreKitManagerError.unknownProduct)
                }

                let didApply = apply(transaction)
                await transaction.finish()
                storeKitDebugLog("Purchase finished: \(transaction.productID), applied=\(didApply)")
                return didApply ? .completed : .failed(StoreKitManagerError.expiredSevenDayPass)
            case .userCancelled:
                storeKitDebugLog("Purchase cancelled: \(productID.rawValue)")
                return .cancelled
            case .pending:
                storeKitDebugLog("Purchase pending: \(productID.rawValue)")
                return .pending
            @unknown default:
                return .failed(StoreKitManagerError.unknownResult)
            }
        } catch {
            purchaseError = error
            storeKitDebugLog("Purchase failed: \(productID.rawValue), \(error.localizedDescription)")
            return .failed(error)
        }
    }

    func restorePurchases() async -> StoreRestoreResult {
        isRestoringPurchases = true
        purchaseError = nil
        defer { isRestoringPurchases = false }

        do {
            storeKitDebugLog("Restore started")
            try await AppStore.sync()
            let summary = await refreshCurrentEntitlements()

            if summary.appliedTransactions > 0 {
                storeKitDebugLog("Restore completed: \(summary.appliedTransactions)")
                return .restored
            }

            storeKitDebugLog("Restore completed: no purchases")
            return .noPurchases
        } catch {
            purchaseError = error
            storeKitDebugLog("Restore failed: \(error.localizedDescription)")
            return .failed(error)
        }
    }

    @discardableResult
    func refreshCurrentEntitlements() async -> StoreEntitlementRefreshSummary {
        var verifiedTransactions = 0
        var appliedTransactions = 0

        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                verifiedTransactions += 1
                if apply(transaction) {
                    appliedTransactions += 1
                }
            } catch {
                storeKitDebugLog("Skipped unverified current entitlement: \(error.localizedDescription)")
            }
        }

        appState?.markTransactionCheck()
        return StoreEntitlementRefreshSummary(
            verifiedTransactions: verifiedTransactions,
            appliedTransactions: appliedTransactions
        )
    }

    private func startTransactionUpdates() {
        transactionUpdatesTask?.cancel()
        transactionUpdatesTask = Task { [weak self] in
            for await result in Transaction.updates {
                await self?.handleTransactionUpdate(result)
            }
        }
    }

    private func handleTransactionUpdate(_ result: VerificationResult<Transaction>) async {
        do {
            let transaction = try checkVerified(result)
            let didApply = apply(transaction)
            await transaction.finish()
            storeKitDebugLog("Transaction update: \(transaction.productID), applied=\(didApply)")
        } catch {
            storeKitDebugLog("Skipped unverified transaction update: \(error.localizedDescription)")
        }
    }

    @discardableResult
    private func apply(_ transaction: Transaction) -> Bool {
        guard let productID = PurchaseProductID.matching(productID: transaction.productID) else {
            return false
        }

        if transaction.revocationDate != nil {
            appState?.revokePurchasedProduct(id: transaction.productID)
            return false
        }

        switch productID {
        case .sevenDayPass:
            let expiry = Calendar.current.date(byAdding: .day, value: 7, to: transaction.purchaseDate) ?? transaction.purchaseDate
            guard expiry > Date() else {
                return false
            }

            return appState?.applyPurchasedProduct(id: transaction.productID, purchaseDate: transaction.purchaseDate) ?? false
        case .lifetimePass:
            return appState?.applyPurchasedProduct(id: transaction.productID, purchaseDate: transaction.purchaseDate) ?? false
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let value):
            return value
        case .unverified:
            throw StoreKitManagerError.unverifiedTransaction
        }
    }

    private func storeKitDebugLog(_ message: String) {
        #if DEBUG
        print("[StoreKit] \(message)")
        #endif
    }

    private func refreshDevelopmentPriceLabelsIfNeeded(loadedProducts: [PurchaseProductID: Product]) {
        #if DEBUG
        guard loadedProducts.count < PurchaseProductID.allCases.count else {
            developmentPriceLabels = [:]
            return
        }

        developmentPriceLabels = loadDevelopmentPriceLabels()
        if !developmentPriceLabels.isEmpty {
            let labels = developmentPriceLabels
                .map { "\($0.key.rawValue)=\($0.value)" }
                .sorted()
                .joined(separator: ", ")
            storeKitDebugLog("Using DEBUG StoreKit price fallback: \(labels)")
        }
        #endif
    }

    #if DEBUG
    private func loadDevelopmentPriceLabels() -> [PurchaseProductID: String] {
        guard let url = Bundle.main.url(forResource: "Memories", withExtension: "storekit") else {
            storeKitDebugLog("DEBUG StoreKit price fallback unavailable: Memories.storekit is not bundled")
            return [:]
        }

        do {
            let data = try Data(contentsOf: url)
            let configuration = try JSONDecoder().decode(DevelopmentStoreKitConfiguration.self, from: data)
            let storefront = configuration.settings?._storefront
            let allProducts = (configuration.products ?? []) + (configuration.nonRenewingSubscriptions ?? [])

            return allProducts.reduce(into: [PurchaseProductID: String]()) { result, product in
                guard
                    let productID = PurchaseProductID.matching(productID: product.productID),
                    !product.displayPrice.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                else {
                    return
                }

                result[productID] = formattedDevelopmentPrice(product.displayPrice, storefront: storefront)
            }
        } catch {
            storeKitDebugLog("DEBUG StoreKit price fallback failed: \(error.localizedDescription)")
            return [:]
        }
    }

    private func formattedDevelopmentPrice(_ price: String, storefront: String?) -> String {
        let trimmedPrice = price.trimmingCharacters(in: .whitespacesAndNewlines)
        let currencySymbols = ["¥", "$", "€", "£", "₩"]
        if currencySymbols.contains(where: { trimmedPrice.hasPrefix($0) }) {
            return trimmedPrice
        }

        switch storefront {
        case "JPN":
            return "¥\(trimmedPrice)"
        default:
            return trimmedPrice
        }
    }
    #endif

    private func logStoreKitEnvironmentIfNeeded() {
        #if DEBUG
        let environment = ProcessInfo.processInfo.environment
        let storeKitEntries = environment
            .filter { key, _ in
                key.localizedCaseInsensitiveContains("storekit")
                    || key.localizedCaseInsensitiveContains("store_kit")
            }
            .map { key, value in "\(key)=\(value)" }
            .sorted()

        if storeKitEntries.isEmpty {
            storeKitDebugLog("No StoreKit-related launch environment values found")
        } else {
            storeKitDebugLog("StoreKit-related launch environment: \(storeKitEntries.joined(separator: " | "))")
        }
        #endif
    }
}

#if DEBUG
private struct DevelopmentStoreKitConfiguration: Decodable {
    let products: [DevelopmentStoreKitProduct]?
    let nonRenewingSubscriptions: [DevelopmentStoreKitProduct]?
    let settings: DevelopmentStoreKitSettings?
}

private struct DevelopmentStoreKitProduct: Decodable {
    let productID: String
    let displayPrice: String
}

private struct DevelopmentStoreKitSettings: Decodable {
    let _storefront: String?
}
#endif

enum StorePurchaseResult {
    case completed
    case cancelled
    case pending
    case productsUnavailable
    case failed(Error)
}

enum StoreRestoreResult {
    case restored
    case noPurchases
    case failed(Error)
}

struct StoreEntitlementRefreshSummary {
    let verifiedTransactions: Int
    let appliedTransactions: Int
}

enum StoreKitManagerError: LocalizedError {
    case unverifiedTransaction
    case unknownProduct
    case unknownResult
    case expiredSevenDayPass

    var errorDescription: String? {
        switch self {
        case .unverifiedTransaction:
            return "The transaction could not be verified."
        case .unknownProduct:
            return "The product is not supported by this app."
        case .unknownResult:
            return "The purchase result is not supported."
        case .expiredSevenDayPass:
            return "The 7-Day Pass is no longer active."
        }
    }
}
