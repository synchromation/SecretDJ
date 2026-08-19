import Foundation

/// A StoreKit product resolved by SKU — a small value type standing in for
/// `StoreKit.Product` (which has no public initializer, so a test fake
/// can't construct one) wherever this feature needs one.
struct PurchasableProduct: Hashable, Identifiable {
	var id: String {
		sku
	}

	let sku: String
	let displayName: String
	let displayPrice: String
}

/// One purchased or restored transaction, in the shape `topupnotify` needs.
/// StoreKit 2 exposes no classic base64 App Store receipt
/// (`secretdjv3/IAPManager.swift`'s `getReceipt()`) — ``jwsRepresentation``
/// (`Transaction.jwsRepresentation`, the transaction's signed JWS payload)
/// is what ``StoreKitProductPurchasing`` sends as `topupnotify`'s `info`
/// blob instead, the StoreKit-2-era stand-in for that receipt.
struct PurchasedTransaction: Hashable, Identifiable {
	let id: UInt64
	let sku: String
	let jwsRepresentation: String
}

/// What ``ProductPurchasing/purchase(_:)`` resolved to.
enum PurchaseAttemptResult: Hashable {
	case success(PurchasedTransaction)
	/// The user dismissed the payment sheet — legacy's
	/// `onAppleTransactionCancelled` (`secretdjv3/TopUpManager.swift`) shows
	/// no toast, just ends the busy state, so this carries no message.
	case userCancelled
	/// Awaiting approval (StoreKit 2's `.pending`, e.g. Ask to Buy) —
	/// legacy's `SKPaymentTransactionState.deferred` branch was a no-op
	/// `break`, so this mirrors that: end the busy state, no toast.
	case pending
}

/// Every way resolving or starting a purchase can fail before any money
/// changes hands — always safe to pair with the tone guide's "No payment
/// was taken." phrase.
enum ProductPurchasingError: Error, Hashable {
	/// No StoreKit product matches the feed's SKU
	/// (`secretdjv3/IAPManager.swift`'s `IAPError.productIdNotFound`).
	case productNotFound
	/// `SKPaymentQueue.canMakePayments() == false`
	/// (`secretdjv3/IAPManager.swift`'s `IAPError.inAppPurchasesNotAllowed`)
	/// — parental controls/restrictions.
	case notAllowed
	/// StoreKit's own purchase/product-lookup call failed.
	case failed
}

/// Abstracts StoreKit 2's `Product.products(for:)`/`Product.purchase()`/
/// `Transaction.unfinished`/`Transaction.finish()`/`AppStore.sync()` behind
/// a seam so nothing in this feature's tests ever touches real StoreKit
/// (PLAN.md S6.7 SCOPE: "tests NEVER touch real StoreKit") —
/// ``StoreKitProductPurchasing`` is the thin real adapter (compiles,
/// exercised only by hand — real StoreKit needs a sandbox/device session no
/// unit test can provide); ``FakeProductPurchasing`` is what every test in
/// this feature drives instead.
protocol ProductPurchasing: Sendable {
	/// Resolves the store's own product for a `topupdetails` SKU —
	/// `secretdjv3/IAPManager.swift`'s `updateTopupsFromStore`/
	/// `findProductFromSku`, minus the "remove unmatched top-ups from the
	/// feed" step (out of this seam's scope — the row is already on screen
	/// by the time a tap resolves a product).
	func product(for sku: String) async throws(ProductPurchasingError) -> PurchasableProduct

	/// Starts a purchase for a resolved product — StoreKit 2's
	/// `Product.purchase()`, the `SKPaymentQueue.add(_:)` equivalent.
	func purchase(_ product: PurchasableProduct) async throws(ProductPurchasingError) -> PurchaseAttemptResult

	/// Every transaction StoreKit currently considers unfinished — its own
	/// durable replacement for legacy's `UserDefaults`-backed
	/// `PendingTopUps` queue (`Transaction.unfinished`, a finite snapshot
	/// sequence that completes once drained, not a live feed).
	/// ``TopUpTransactionListener`` drains this once at startup and again
	/// after ``restorePurchases()``.
	func unfinishedTransactions() -> AsyncStream<PurchasedTransaction>

	/// Marks `transaction` consumed. Call only once its `topupnotify`
	/// outcome is credited or already-processed — never on a retryable or
	/// hard failure, so it reappears on ``unfinishedTransactions()`` for a
	/// later drain to retry (``TopUpNotifySubmitter``'s doc comment).
	func finish(_ transaction: PurchasedTransaction) async

	/// Triggers StoreKit 2's `AppStore.sync()`
	/// (`secretdjv3/IAPManager.swift`'s `restorePurchases()`); any
	/// transaction still unfinished afterward reappears on a fresh
	/// ``unfinishedTransactions()`` call for the caller to drain.
	func restorePurchases() async throws(ProductPurchasingError)
}
