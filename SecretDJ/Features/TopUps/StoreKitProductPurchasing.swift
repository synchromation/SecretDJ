import StoreKit

/// The real ``ProductPurchasing``: StoreKit 2's `Product`/`Transaction` API.
/// Compiles as part of every `Scripts/verify.sh` run but is exercised only
/// by hand — real StoreKit purchases need a sandbox/App Store Connect
/// session no unit test can provide (PLAN.md S6.7 SCOPE: "The StoreKit
/// adapter compiles but is exercised only by hand later"). An `actor`
/// (rather than a plain `struct`) because it keeps a lookup of the real
/// `StoreKit.Transaction` objects behind each ``PurchasedTransaction`` id —
/// `Transaction.finish()` is an instance method with no "finish by id" free
/// function, so ``finish(_:)`` needs somewhere durable-for-the-process to
/// find the object again.
actor StoreKitProductPurchasing: ProductPurchasing {
	private var transactionsByID: [UInt64: Transaction] = [:]

	func product(for sku: String) async throws(ProductPurchasingError) -> PurchasableProduct {
		let products: [Product]
		do {
			products = try await Product.products(for: [sku])
		} catch {
			throw ProductPurchasingError.failed
		}

		guard let product = products.first else {
			throw ProductPurchasingError.productNotFound
		}

		return PurchasableProduct(sku: product.id, displayName: product.displayName, displayPrice: product.displayPrice)
	}

	func purchase(_ product: PurchasableProduct) async throws(ProductPurchasingError) -> PurchaseAttemptResult {
		guard AppStore.canMakePayments else {
			throw ProductPurchasingError.notAllowed
		}

		let storeProducts: [Product]
		do {
			storeProducts = try await Product.products(for: [product.sku])
		} catch {
			throw ProductPurchasingError.failed
		}

		guard let storeProduct = storeProducts.first else {
			throw ProductPurchasingError.productNotFound
		}

		let result: Product.PurchaseResult
		do {
			result = try await storeProduct.purchase()
		} catch {
			throw ProductPurchasingError.failed
		}

		switch result {
		case .success(let verification):
			guard case .verified(let transaction) = verification else {
				throw ProductPurchasingError.failed
			}
			remember(transaction)
			return .success(Self.purchasedTransaction(from: transaction, verification: verification))

		case .userCancelled:
			return .userCancelled

		case .pending:
			return .pending

		@unknown default:
			return .pending
		}
	}

	/// Wraps `Transaction.unfinished` — a finite snapshot sequence that
	/// completes once StoreKit has yielded every currently unfinished
	/// transaction (``ProductPurchasing/unfinishedTransactions()``'s doc
	/// comment).
	nonisolated func unfinishedTransactions() -> AsyncStream<PurchasedTransaction> {
		AsyncStream { continuation in
			let task = Task {
				for await result in Transaction.unfinished {
					guard case .verified(let transaction) = result else { continue }
					await remember(transaction)
					continuation.yield(Self.purchasedTransaction(from: transaction, verification: result))
				}
				continuation.finish()
			}
			continuation.onTermination = { _ in task.cancel() }
		}
	}

	func finish(_ transaction: PurchasedTransaction) async {
		guard let storeKitTransaction = transactionsByID[transaction.id] else { return }
		await storeKitTransaction.finish()
		transactionsByID[transaction.id] = nil
	}

	func restorePurchases() async throws(ProductPurchasingError) {
		do {
			try await AppStore.sync()
		} catch {
			throw ProductPurchasingError.failed
		}
	}

	private func remember(_ transaction: Transaction) {
		transactionsByID[transaction.id] = transaction
	}

	private nonisolated static func purchasedTransaction(
		from transaction: Transaction,
		verification: VerificationResult<Transaction>,
	) -> PurchasedTransaction {
		PurchasedTransaction(
			id: transaction.id,
			sku: transaction.productID,
			jwsRepresentation: verification.jwsRepresentation,
		)
	}
}
