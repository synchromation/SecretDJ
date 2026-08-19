import Foundation

/// A scriptable ``ProductPurchasing`` fake for tests and previews — never
/// touches real StoreKit (PLAN.md S6.7 SCOPE).
@MainActor
final class FakeProductPurchasing: ProductPurchasing {
	var productResult: Result<PurchasableProduct, ProductPurchasingError>
	var purchaseResult: Result<PurchaseAttemptResult, ProductPurchasingError>
	var restorePurchasesResult: Result<Void, ProductPurchasingError> = .success(())

	private(set) var productInvocations: [String] = []
	private(set) var purchaseInvocations: [PurchasableProduct] = []
	private(set) var finishedTransactions: [PurchasedTransaction] = []
	private(set) var restorePurchasesCallCount = 0

	private var unfinishedContinuation: AsyncStream<PurchasedTransaction>.Continuation?
	private var isHangingPurchase = false
	private var purchaseContinuation: CheckedContinuation<Void, Never>?

	init(
		productResult: Result<PurchasableProduct, ProductPurchasingError> = .failure(.productNotFound),
		purchaseResult: Result<PurchaseAttemptResult, ProductPurchasingError> = .failure(.failed),
	) {
		self.productResult = productResult
		self.purchaseResult = purchaseResult
	}

	func product(for sku: String) async throws(ProductPurchasingError) -> PurchasableProduct {
		productInvocations.append(sku)
		switch productResult {
		case .success(let product): return product
		case .failure(let error): throw error
		}
	}

	func purchase(_ product: PurchasableProduct) async throws(ProductPurchasingError) -> PurchaseAttemptResult {
		purchaseInvocations.append(product)

		if isHangingPurchase {
			await withCheckedContinuation { purchaseContinuation = $0 }
		}

		switch purchaseResult {
		case .success(let result): return result
		case .failure(let error): throw error
		}
	}

	/// Makes the next ``purchase(_:)`` call suspend until ``resumePurchase()``
	/// releases it — lets a test observe ``TopUpPurchaseModel/isPurchasing``
	/// mid-flight (mirrors `InMemoryLikeToggling`'s `hang()`/`resume(with:)`).
	func hangPurchase() {
		isHangingPurchase = true
	}

	func resumePurchase() {
		isHangingPurchase = false
		purchaseContinuation?.resume()
		purchaseContinuation = nil
	}

	/// A fresh stream every call, matching real `Transaction.unfinished`'s
	/// per-access snapshot semantics (``ProductPurchasing/unfinishedTransactions()``'s
	/// doc comment) — a test drives the currently open one with
	/// ``emitUnfinished(_:)``/``finishUnfinishedStream()``.
	func unfinishedTransactions() -> AsyncStream<PurchasedTransaction> {
		AsyncStream { continuation in
			self.unfinishedContinuation = continuation
		}
	}

	/// Pushes `transaction` onto the currently open
	/// ``unfinishedTransactions()`` stream, simulating StoreKit surfacing an
	/// unfinished transaction. A no-op before anything has called
	/// ``unfinishedTransactions()``.
	func emitUnfinished(_ transaction: PurchasedTransaction) {
		unfinishedContinuation?.yield(transaction)
	}

	/// Ends the currently open stream, so a `for await` loop draining it
	/// completes — mirrors `Transaction.unfinished` finishing once its
	/// current snapshot has been enumerated.
	func finishUnfinishedStream() {
		unfinishedContinuation?.finish()
	}

	func finish(_ transaction: PurchasedTransaction) async {
		finishedTransactions.append(transaction)
	}

	func restorePurchases() async throws(ProductPurchasingError) {
		restorePurchasesCallCount += 1
		if case .failure(let error) = restorePurchasesResult {
			throw error
		}
	}
}
