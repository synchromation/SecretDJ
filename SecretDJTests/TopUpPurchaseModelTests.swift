import Observability
import SecretDJAPI
import SecretDJDomain
import Testing

@testable import SecretDJ

/// ``TopUpPurchaseModel`` — the per-row purchase flow (PLAN.md S6.7 SCOPE):
/// tap a top-up row, resolve the StoreKit product by SKU, purchase, then
/// submit via `topupnotify` through ``TopUpNotifySubmitter``. Typed
/// pre-payment failures pair with the tone guide's load-bearing "No payment
/// was taken." phrase; a post-payment `topupnotify` failure never does,
/// since StoreKit already took the money by then.
@MainActor
enum TopUpPurchaseModelTests {
	struct `Starting up` {
		@Test func `starts idle`() {
			let model = makeModel()

			#expect(!model.isPurchasing)
			#expect(model.toastEvent == nil)
		}
	}

	struct `Purchasing, before StoreKit resolves a product` {
		@Test func `shows the no-payment-taken fallback when the SKU can't be resolved`() async {
			let purchasing = FakeProductPurchasing(productResult: .failure(.productNotFound))
			let model = makeModel(purchasing: purchasing)

			await model.purchase(makeTopUp())

			#expect(model.toastEvent?.message.contains("No payment was taken.") == true)
		}

		@Test func `never starts a purchase when the SKU can't be resolved`() async {
			let purchasing = FakeProductPurchasing(productResult: .failure(.productNotFound))
			let model = makeModel(purchasing: purchasing)

			await model.purchase(makeTopUp())

			#expect(purchasing.purchaseInvocations.isEmpty)
			#expect(!model.isPurchasing)
		}
	}

	struct `Purchasing, when StoreKit's own purchase call fails` {
		@Test func `shows the no-payment-taken fallback`() async {
			let purchasing = FakeProductPurchasing(
				productResult: .success(makeProduct()),
				purchaseResult: .failure(.failed),
			)
			let model = makeModel(purchasing: purchasing)

			await model.purchase(makeTopUp())

			#expect(model.toastEvent?.message.contains("No payment was taken.") == true)
		}
	}

	struct `Purchasing, when the user cancels` {
		@Test func `shows no toast`() async {
			let purchasing = FakeProductPurchasing(
				productResult: .success(makeProduct()),
				purchaseResult: .success(.userCancelled),
			)
			let model = makeModel(purchasing: purchasing)

			await model.purchase(makeTopUp())

			#expect(model.toastEvent == nil)
		}

		@Test func `ends the busy state`() async {
			let purchasing = FakeProductPurchasing(
				productResult: .success(makeProduct()),
				purchaseResult: .success(.userCancelled),
			)
			let model = makeModel(purchasing: purchasing)

			await model.purchase(makeTopUp())

			#expect(!model.isPurchasing)
		}
	}

	struct `Purchasing, when the purchase is pending (Ask to Buy)` {
		@Test func `shows no toast`() async {
			let purchasing = FakeProductPurchasing(
				productResult: .success(makeProduct()),
				purchaseResult: .success(.pending),
			)
			let model = makeModel(purchasing: purchasing)

			await model.purchase(makeTopUp())

			#expect(model.toastEvent == nil)
		}
	}

	struct `Purchasing, when the purchase succeeds and the server credits it` {
		@Test func `shows the server's credited message`() async {
			let purchasing = FakeProductPurchasing(
				productResult: .success(makeProduct()),
				purchaseResult: .success(.success(makeTransaction())),
			)
			let servicing = InMemoryTopUpsServicing(
				notifyPurchaseResult: .success(TopUpNotifyServiceResult(
					outcome: .credited(message: "You've got 20 more credits!"),
					rotatedToken: nil,
				)),
			)
			let model = makeModel(purchasing: purchasing, servicing: servicing)

			await model.purchase(makeTopUp())

			#expect(model.toastEvent?.message == "You've got 20 more credits!")
		}

		@Test func `finishes the transaction`() async {
			let transaction = makeTransaction()
			let purchasing = FakeProductPurchasing(
				productResult: .success(makeProduct()),
				purchaseResult: .success(.success(transaction)),
			)
			let servicing = InMemoryTopUpsServicing(
				notifyPurchaseResult: .success(TopUpNotifyServiceResult(
					outcome: .credited(message: "Nice one"),
					rotatedToken: nil,
				)),
			)
			let model = makeModel(purchasing: purchasing, servicing: servicing)

			await model.purchase(makeTopUp())

			#expect(purchasing.finishedTransactions == [transaction])
		}

		@Test func `rotates the session's token when the outcome carries one`() async {
			let purchasing = FakeProductPurchasing(
				productResult: .success(makeProduct()),
				purchaseResult: .success(.success(makeTransaction())),
			)
			let servicing = InMemoryTopUpsServicing(
				notifyPurchaseResult: .success(TopUpNotifyServiceResult(
					outcome: .credited(message: "Nice one"),
					rotatedToken: "new-tok",
				)),
			)
			let sessionStore = makeSessionStore()
			let model = makeModel(purchasing: purchasing, servicing: servicing, sessionStore: sessionStore)

			await model.purchase(makeTopUp())

			#expect(sessionStore.credential == APICredential(token: "new-tok", passwordHash: "hash"))
		}
	}

	struct `Purchasing, when the purchase succeeds but the server already processed it` {
		@Test func `shows the server's message`() async {
			let purchasing = FakeProductPurchasing(
				productResult: .success(makeProduct()),
				purchaseResult: .success(.success(makeTransaction())),
			)
			let servicing = InMemoryTopUpsServicing(
				notifyPurchaseResult: .success(TopUpNotifyServiceResult(
					outcome: .alreadyProcessed(message: "Already sorted!"),
					rotatedToken: nil,
				)),
			)
			let model = makeModel(purchasing: purchasing, servicing: servicing)

			await model.purchase(makeTopUp())

			#expect(model.toastEvent?.message == "Already sorted!")
		}
	}

	struct `Purchasing, when the purchase succeeds but the server says retry` {
		@Test func `shows no toast, leaving the listener to retry silently`() async {
			let purchasing = FakeProductPurchasing(
				productResult: .success(makeProduct()),
				purchaseResult: .success(.success(makeTransaction())),
			)
			let servicing = InMemoryTopUpsServicing(
				notifyPurchaseResult: .success(TopUpNotifyServiceResult(outcome: .retryable, rotatedToken: nil)),
			)
			let model = makeModel(purchasing: purchasing, servicing: servicing)

			await model.purchase(makeTopUp())

			#expect(model.toastEvent == nil)
		}

		@Test func `does not finish the transaction`() async {
			let purchasing = FakeProductPurchasing(
				productResult: .success(makeProduct()),
				purchaseResult: .success(.success(makeTransaction())),
			)
			let servicing = InMemoryTopUpsServicing(
				notifyPurchaseResult: .success(TopUpNotifyServiceResult(outcome: .retryable, rotatedToken: nil)),
			)
			let model = makeModel(purchasing: purchasing, servicing: servicing)

			await model.purchase(makeTopUp())

			#expect(purchasing.finishedTransactions.isEmpty)
		}
	}

	struct `Purchasing, when the purchase succeeds but the server hard-fails verification` {
		@Test func `shows the server's own failure message, never the no-payment-taken phrase`() async {
			let purchasing = FakeProductPurchasing(
				productResult: .success(makeProduct()),
				purchaseResult: .success(.success(makeTransaction())),
			)
			let servicing = InMemoryTopUpsServicing(
				notifyPurchaseResult: .success(TopUpNotifyServiceResult(
					outcome: .failure(message: "Sorry, that receipt looks wrong"),
					rotatedToken: nil,
				)),
			)
			let model = makeModel(purchasing: purchasing, servicing: servicing)

			await model.purchase(makeTopUp())

			#expect(model.toastEvent?.message == "Sorry, that receipt looks wrong")
			#expect(model.toastEvent?.message.contains("No payment was taken.") == false)
		}

		@Test func `falls back to a generic message when the server sends none`() async {
			let purchasing = FakeProductPurchasing(
				productResult: .success(makeProduct()),
				purchaseResult: .success(.success(makeTransaction())),
			)
			let servicing = InMemoryTopUpsServicing(
				notifyPurchaseResult: .success(TopUpNotifyServiceResult(
					outcome: .failure(message: ""),
					rotatedToken: nil,
				)),
			)
			let model = makeModel(purchasing: purchasing, servicing: servicing)

			await model.purchase(makeTopUp())

			#expect(model.toastEvent?.message != nil)
			#expect(model.toastEvent?.message.contains("No payment was taken.") == false)
		}
	}

	struct `Purchasing, concurrency and session guards` {
		@Test func `ignores a second purchase call while one is already in flight`() async {
			let purchasing = FakeProductPurchasing(productResult: .success(makeProduct()))
			purchasing.hangPurchase()
			let model = makeModel(purchasing: purchasing)

			async let first: Void = model.purchase(makeTopUp())
			await Task.yield()
			await model.purchase(makeTopUp())

			#expect(purchasing.purchaseInvocations.count == 1)

			purchasing.purchaseResult = .success(.userCancelled)
			purchasing.resumePurchase()
			await first
		}

		@Test func `sets isPurchasing while a purchase is in flight`() async {
			let purchasing = FakeProductPurchasing(productResult: .success(makeProduct()))
			purchasing.hangPurchase()
			let model = makeModel(purchasing: purchasing)

			async let purchase: Void = model.purchase(makeTopUp())
			await Task.yield()

			#expect(model.isPurchasing)

			purchasing.purchaseResult = .success(.userCancelled)
			purchasing.resumePurchase()
			await purchase
		}

		@Test func `does nothing when no session is signed in`() async {
			let purchasing = FakeProductPurchasing(productResult: .success(makeProduct()))
			let model = makeModel(purchasing: purchasing, sessionStore: makeSignedOutSessionStore())

			await model.purchase(makeTopUp())

			#expect(purchasing.productInvocations.isEmpty)
			#expect(model.toastEvent == nil)
		}
	}

	struct Instrumentation {
		@Test func `tracks purchaseInitiated and purchaseCompleted on a credited purchase`() async {
			let purchasing = FakeProductPurchasing(
				productResult: .success(makeProduct()),
				purchaseResult: .success(.success(makeTransaction())),
			)
			let servicing = InMemoryTopUpsServicing(
				notifyPurchaseResult: .success(TopUpNotifyServiceResult(
					outcome: .credited(message: "Nice"),
					rotatedToken: nil,
				)),
			)
			let recorder = RecordingDestination()
			let model = makeModel(
				purchasing: purchasing,
				servicing: servicing,
				observability: ObservabilityPipeline(destinations: [recorder]),
			)

			await model.purchase(makeTopUp())

			#expect(recorder.analytics.map(\.name) == ["purchaseInitiated", "purchaseCompleted"])
		}

		@Test func `tracks purchaseFailed and reports the error when StoreKit's purchase call fails`() async {
			let purchasing = FakeProductPurchasing(
				productResult: .success(makeProduct()),
				purchaseResult: .failure(.failed),
			)
			let recorder = RecordingDestination()
			let model = makeModel(
				purchasing: purchasing,
				observability: ObservabilityPipeline(destinations: [recorder]),
			)

			await model.purchase(makeTopUp())

			#expect(recorder.analytics.map(\.name) == ["purchaseInitiated", "purchaseFailed"])
			#expect(recorder.breadcrumbs.contains { if case .interaction = $0 { true } else { false } })
		}
	}
}

// MARK: - Fixtures

private func makeTopUp() -> TopUp {
	TopUp(
		sku: "credits.20",
		vendor: .appleAppStore,
		name: "20 credits",
		productDescription: "",
		price: "£1.99",
		displayPrice: "£1.99",
		currencyCode: "GBP",
		url: nil,
		numCredits: 20,
		text: "",
		sortIndex: 0,
		action: nil,
		actions: [],
	)
}

private func makeProduct() -> PurchasableProduct {
	PurchasableProduct(sku: "credits.20", displayName: "20 credits", displayPrice: "£1.99")
}

private func makeTransaction() -> PurchasedTransaction {
	PurchasedTransaction(id: 1, sku: "credits.20", jwsRepresentation: "jws-blob")
}

@MainActor
private func makeSessionStore() -> SessionStore {
	let store = SessionStore(snapshotStore: InMemorySessionSnapshotStore(), credentialStore: InMemoryCredentialStore())
	store.signIn(
		user: SessionUser(personId: "9", screenName: "TurboTim"),
		venue: nil,
		credential: APICredential(token: "tok", passwordHash: "hash"),
	)
	return store
}

@MainActor
private func makeSignedOutSessionStore() -> SessionStore {
	SessionStore(snapshotStore: InMemorySessionSnapshotStore(), credentialStore: InMemoryCredentialStore())
}

@MainActor
private func makeModel(
	purchasing: FakeProductPurchasing = FakeProductPurchasing(),
	servicing: InMemoryTopUpsServicing = InMemoryTopUpsServicing(),
	sessionStore: SessionStore? = nil,
	observability: ObservabilityPipeline = .disabled,
) -> TopUpPurchaseModel {
	TopUpPurchaseModel(
		purchasing: purchasing,
		servicing: servicing,
		sessionStore: sessionStore ?? makeSessionStore(),
		observability: observability,
	)
}
