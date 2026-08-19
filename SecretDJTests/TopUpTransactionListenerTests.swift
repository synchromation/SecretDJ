import Observability
import SecretDJAPI
import SecretDJDomain
import Testing

@testable import SecretDJ

/// ``TopUpTransactionListener`` — replaces legacy's resubmit-on-every-
/// screen-appearance loop (`TopUpManager.resubmitPendingTopUps`, called
/// from half a dozen `viewDidAppear`s) with a single startup drain of
/// StoreKit's own durable unfinished-transaction queue, plus the "Restore
/// Purchases" flow: restored transactions notify with the `purchaseRestored`
/// flag, and `numpaidcredits` drives the nothing-to-restore message
/// (`secretdjv3/TopUpManager.swift`'s `onNoPurchasesToRestore` — PLAN.md
/// S6.7 SCOPE).
@MainActor
enum TopUpTransactionListenerTests {
	struct `Starting up` {
		@Test func `starts idle, with no toast`() {
			let listener = makeListener()

			#expect(!listener.isRestoring)
			#expect(listener.toastEvent == nil)
		}
	}

	struct `Draining unfinished transactions at startup` {
		@Test func `submits every unfinished transaction as a fresh payment`() async {
			let purchasing = FakeProductPurchasing()
			let servicing = InMemoryTopUpsServicing(
				notifyPurchaseResult: .success(TopUpNotifyServiceResult(
					outcome: .credited(message: "Nice"),
					rotatedToken: nil,
				)),
			)
			let listener = makeListener(purchasing: purchasing, servicing: servicing)

			async let drain: Void = listener.start()
			await Task.yield()
			purchasing.emitUnfinished(makeTransaction(id: 1))
			purchasing.emitUnfinished(makeTransaction(id: 2))
			purchasing.finishUnfinishedStream()
			await drain

			#expect(servicing.notifyPurchaseInvocations.map(\.transactionId) == ["1", "2"])
			#expect(servicing.notifyPurchaseInvocations.allSatisfy { $0.action == .paymentReceived })
		}

		@Test func `finishes a transaction the server credits`() async {
			let purchasing = FakeProductPurchasing()
			let servicing = InMemoryTopUpsServicing(
				notifyPurchaseResult: .success(TopUpNotifyServiceResult(
					outcome: .credited(message: "Nice"),
					rotatedToken: nil,
				)),
			)
			let listener = makeListener(purchasing: purchasing, servicing: servicing)
			let transaction = makeTransaction(id: 1)

			async let drain: Void = listener.start()
			await Task.yield()
			purchasing.emitUnfinished(transaction)
			purchasing.finishUnfinishedStream()
			await drain

			#expect(purchasing.finishedTransactions == [transaction])
			#expect(listener.toastEvent?.message == "Nice")
		}

		@Test func `leaves a retryable transaction unfinished, silently`() async {
			let purchasing = FakeProductPurchasing()
			let servicing = InMemoryTopUpsServicing(
				notifyPurchaseResult: .success(TopUpNotifyServiceResult(outcome: .retryable, rotatedToken: nil)),
			)
			let listener = makeListener(purchasing: purchasing, servicing: servicing)

			async let drain: Void = listener.start()
			await Task.yield()
			purchasing.emitUnfinished(makeTransaction(id: 1))
			purchasing.finishUnfinishedStream()
			await drain

			#expect(purchasing.finishedTransactions.isEmpty)
			#expect(listener.toastEvent == nil)
		}

		@Test func `does nothing when nothing is unfinished`() async {
			let purchasing = FakeProductPurchasing()
			let servicing = InMemoryTopUpsServicing()
			let listener = makeListener(purchasing: purchasing, servicing: servicing)

			async let drain: Void = listener.start()
			await Task.yield()
			purchasing.finishUnfinishedStream()
			await drain

			#expect(servicing.notifyPurchaseInvocations.isEmpty)
			#expect(listener.toastEvent == nil)
		}
	}

	struct `Restoring purchases, when StoreKit finds something` {
		@Test func `submits each with the purchaseRestored flag`() async throws {
			let purchasing = FakeProductPurchasing()
			let servicing = InMemoryTopUpsServicing(
				notifyPurchaseResult: .success(TopUpNotifyServiceResult(
					outcome: .credited(message: "Nice"),
					rotatedToken: nil,
				)),
			)
			let listener = makeListener(purchasing: purchasing, servicing: servicing)

			async let restore: Void = listener.restore()
			await Task.yield()
			purchasing.emitUnfinished(makeTransaction(id: 1))
			purchasing.finishUnfinishedStream()
			await restore

			let invocation = try #require(servicing.notifyPurchaseInvocations.first)
			#expect(invocation.action == .purchaseRestored)
		}

		@Test func `never queries numPaidCredits`() async {
			let purchasing = FakeProductPurchasing()
			let servicing = InMemoryTopUpsServicing(
				notifyPurchaseResult: .success(TopUpNotifyServiceResult(
					outcome: .credited(message: "Nice"),
					rotatedToken: nil,
				)),
			)
			let listener = makeListener(purchasing: purchasing, servicing: servicing)

			async let restore: Void = listener.restore()
			await Task.yield()
			purchasing.emitUnfinished(makeTransaction(id: 1))
			purchasing.finishUnfinishedStream()
			await restore

			#expect(servicing.numPaidCreditsInvocations.isEmpty)
		}
	}

	struct `Restoring purchases, when StoreKit finds nothing` {
		@Test func `shows the server's paid-credit count`() async {
			let purchasing = FakeProductPurchasing()
			let servicing = InMemoryTopUpsServicing(
				numPaidCreditsResult: .success(NumPaidCreditsServiceResult(
					text: "You have 4 credits",
					rotatedToken: nil,
				)),
			)
			let listener = makeListener(purchasing: purchasing, servicing: servicing)

			async let restore: Void = listener.restore()
			await Task.yield()
			purchasing.finishUnfinishedStream()
			await restore

			#expect(listener.toastEvent?.message.contains("You have 4 credits") == true)
		}

		@Test func `still shows a message when numPaidCredits itself fails`() async {
			let purchasing = FakeProductPurchasing()
			let servicing = InMemoryTopUpsServicing(numPaidCreditsResult: .failure(.connection))
			let listener = makeListener(purchasing: purchasing, servicing: servicing)

			async let restore: Void = listener.restore()
			await Task.yield()
			purchasing.finishUnfinishedStream()
			await restore

			#expect(listener.toastEvent != nil)
		}
	}

	struct `Restoring purchases, busy state and failure` {
		@Test func `sets isRestoring while restoring`() async {
			let purchasing = FakeProductPurchasing()
			purchasing.restorePurchasesResult = .success(())
			let listener = makeListener(purchasing: purchasing)

			async let restore: Void = listener.restore()
			await Task.yield()

			#expect(listener.isRestoring)

			purchasing.finishUnfinishedStream()
			await restore
			#expect(!listener.isRestoring)
		}

		@Test func `shows a toast when StoreKit's own restore call fails`() async {
			let purchasing = FakeProductPurchasing()
			purchasing.restorePurchasesResult = .failure(.failed)
			let listener = makeListener(purchasing: purchasing)

			await listener.restore()

			#expect(listener.toastEvent != nil)
			#expect(!listener.isRestoring)
		}

		@Test func `ignores a second restore call while one is already in flight`() async {
			let purchasing = FakeProductPurchasing()
			let listener = makeListener(purchasing: purchasing)

			async let first: Void = listener.restore()
			await Task.yield()
			async let second: Void = listener.restore()
			await Task.yield()

			#expect(purchasing.restorePurchasesCallCount == 1)

			purchasing.finishUnfinishedStream()
			await first
			await second
		}
	}
}

// MARK: - Fixtures

private func makeTransaction(id: UInt64) -> PurchasedTransaction {
	PurchasedTransaction(id: id, sku: "credits.20", jwsRepresentation: "jws-\(id)")
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
private func makeListener(
	purchasing: FakeProductPurchasing = FakeProductPurchasing(),
	servicing: InMemoryTopUpsServicing = InMemoryTopUpsServicing(),
	sessionStore: SessionStore? = nil,
	observability: ObservabilityPipeline = .disabled,
) -> TopUpTransactionListener {
	TopUpTransactionListener(
		purchasing: purchasing,
		servicing: servicing,
		sessionStore: sessionStore ?? makeSessionStore(),
		observability: observability,
	)
}
