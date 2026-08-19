import SecretDJAPI
import SecretDJDomain
import Testing

@testable import SecretDJ

/// ``TopUpNotifySubmitter`` — the shared `topupnotify` submit-then-finish
/// decision, replacing legacy's finish-before-verify ordering
/// (`secretdjv3/IAPManager.swift`'s `paymentQueue(_:updatedTransactions:)`
/// calls `SKPaymentQueue.default().finishTransaction` unconditionally,
/// before the server call even starts) with StoreKit 2's own durable
/// unfinished-transaction queue as the safety net: only `credited`/
/// `alreadyProcessed` finish; `retryable` and a hard `failure` both leave
/// the transaction unfinished so a later drain retries it (PLAN.md S6.7
/// SCOPE).
@MainActor
enum TopUpNotifySubmitterTests {
	struct `Submitting, when the server credits the account` {
		@Test func `finishes the transaction`() async {
			let purchasing = FakeProductPurchasing()
			let servicing = InMemoryTopUpsServicing(
				notifyPurchaseResult: .success(TopUpNotifyServiceResult(
					outcome: .credited(message: "You've got 20 more credits!"),
					rotatedToken: nil,
				)),
			)
			let submitter = TopUpNotifySubmitter(purchasing: purchasing, servicing: servicing)
			let transaction = makeTransaction()

			_ = await submitter.submit(transaction, action: .paymentReceived, userId: "9", credential: makeCredential())

			#expect(purchasing.finishedTransactions == [transaction])
		}

		@Test func `returns the server's credited message and any rotated token`() async {
			let purchasing = FakeProductPurchasing()
			let servicing = InMemoryTopUpsServicing(
				notifyPurchaseResult: .success(TopUpNotifyServiceResult(
					outcome: .credited(message: "You've got 20 more credits!"),
					rotatedToken: "new-tok",
				)),
			)
			let submitter = TopUpNotifySubmitter(purchasing: purchasing, servicing: servicing)

			let result = await submitter.submit(
				makeTransaction(),
				action: .paymentReceived,
				userId: "9",
				credential: makeCredential(),
			)

			#expect(result == TopUpNotifySubmissionResult(
				outcome: .credited(message: "You've got 20 more credits!"),
				rotatedToken: "new-tok",
			))
		}
	}

	struct `Submitting, when the server reports already processed` {
		@Test func `finishes the transaction`() async {
			let purchasing = FakeProductPurchasing()
			let servicing = InMemoryTopUpsServicing(
				notifyPurchaseResult: .success(TopUpNotifyServiceResult(
					outcome: .alreadyProcessed(message: "Already sorted!"),
					rotatedToken: nil,
				)),
			)
			let submitter = TopUpNotifySubmitter(purchasing: purchasing, servicing: servicing)
			let transaction = makeTransaction()

			_ = await submitter.submit(transaction, action: .paymentReceived, userId: "9", credential: makeCredential())

			#expect(purchasing.finishedTransactions == [transaction])
		}

		@Test func `returns the server's message`() async {
			let purchasing = FakeProductPurchasing()
			let servicing = InMemoryTopUpsServicing(
				notifyPurchaseResult: .success(TopUpNotifyServiceResult(
					outcome: .alreadyProcessed(message: "Already sorted!"),
					rotatedToken: nil,
				)),
			)
			let submitter = TopUpNotifySubmitter(purchasing: purchasing, servicing: servicing)

			let result = await submitter.submit(
				makeTransaction(),
				action: .paymentReceived,
				userId: "9",
				credential: makeCredential(),
			)

			#expect(result.outcome == .alreadyProcessed(message: "Already sorted!"))
		}
	}

	struct `Submitting, when the server says retry` {
		@Test func `does not finish the transaction`() async {
			let purchasing = FakeProductPurchasing()
			let servicing = InMemoryTopUpsServicing(
				notifyPurchaseResult: .success(TopUpNotifyServiceResult(outcome: .retryable, rotatedToken: nil)),
			)
			let submitter = TopUpNotifySubmitter(purchasing: purchasing, servicing: servicing)

			_ = await submitter.submit(
				makeTransaction(),
				action: .paymentReceived,
				userId: "9",
				credential: makeCredential(),
			)

			#expect(purchasing.finishedTransactions.isEmpty)
		}

		@Test func `returns retryable`() async {
			let purchasing = FakeProductPurchasing()
			let servicing = InMemoryTopUpsServicing(
				notifyPurchaseResult: .success(TopUpNotifyServiceResult(outcome: .retryable, rotatedToken: nil)),
			)
			let submitter = TopUpNotifySubmitter(purchasing: purchasing, servicing: servicing)

			let result = await submitter.submit(
				makeTransaction(),
				action: .paymentReceived,
				userId: "9",
				credential: makeCredential(),
			)

			#expect(result.outcome == .retryable)
		}
	}

	struct `Submitting, when the server reports a hard failure` {
		@Test func `does not finish the transaction`() async {
			let purchasing = FakeProductPurchasing()
			let servicing = InMemoryTopUpsServicing(
				notifyPurchaseResult: .success(TopUpNotifyServiceResult(
					outcome: .failure(message: "Sorry, that receipt looks wrong"),
					rotatedToken: nil,
				)),
			)
			let submitter = TopUpNotifySubmitter(purchasing: purchasing, servicing: servicing)

			_ = await submitter.submit(
				makeTransaction(),
				action: .paymentReceived,
				userId: "9",
				credential: makeCredential(),
			)

			#expect(purchasing.finishedTransactions.isEmpty)
		}

		@Test func `returns the server's failure message`() async {
			let purchasing = FakeProductPurchasing()
			let servicing = InMemoryTopUpsServicing(
				notifyPurchaseResult: .success(TopUpNotifyServiceResult(
					outcome: .failure(message: "Sorry, that receipt looks wrong"),
					rotatedToken: nil,
				)),
			)
			let submitter = TopUpNotifySubmitter(purchasing: purchasing, servicing: servicing)

			let result = await submitter.submit(
				makeTransaction(),
				action: .paymentReceived,
				userId: "9",
				credential: makeCredential(),
			)

			#expect(result.outcome == .failed(message: "Sorry, that receipt looks wrong"))
		}
	}

	struct `Submitting, when the service call itself fails` {
		@Test func `does not finish the transaction`() async {
			let purchasing = FakeProductPurchasing()
			let servicing = InMemoryTopUpsServicing(notifyPurchaseResult: .failure(.connection))
			let submitter = TopUpNotifySubmitter(purchasing: purchasing, servicing: servicing)

			_ = await submitter.submit(
				makeTransaction(),
				action: .paymentReceived,
				userId: "9",
				credential: makeCredential(),
			)

			#expect(purchasing.finishedTransactions.isEmpty)
		}

		@Test func `is treated as retryable, since StoreKit's own durable queue is the safety net`() async {
			let purchasing = FakeProductPurchasing()
			let servicing = InMemoryTopUpsServicing(notifyPurchaseResult: .failure(.connection))
			let submitter = TopUpNotifySubmitter(purchasing: purchasing, servicing: servicing)

			let result = await submitter.submit(
				makeTransaction(),
				action: .paymentReceived,
				userId: "9",
				credential: makeCredential(),
			)

			#expect(result.outcome == .retryable)
		}
	}

	struct `Submitting, the request sent to the server` {
		@Test func `carries the transaction's id, sku-derived receipt, action, userId, and credential`() async throws {
			let purchasing = FakeProductPurchasing()
			let servicing = InMemoryTopUpsServicing(
				notifyPurchaseResult: .success(TopUpNotifyServiceResult(outcome: .retryable, rotatedToken: nil)),
			)
			let submitter = TopUpNotifySubmitter(purchasing: purchasing, servicing: servicing)
			let transaction = PurchasedTransaction(id: 555, sku: "credits.20", jwsRepresentation: "jws-blob")

			_ = await submitter.submit(
				transaction,
				action: .purchaseRestored,
				userId: "9",
				credential: makeCredential(),
			)

			let invocation = try #require(servicing.notifyPurchaseInvocations.first)
			#expect(invocation.userId == "9")
			#expect(invocation.vendor == .appleAppStore)
			#expect(invocation.action == .purchaseRestored)
			#expect(invocation.transactionId == "555")
			#expect(invocation.receiptBase64 == "jws-blob")
			#expect(invocation.credential == makeCredential())
		}
	}
}

// MARK: - Fixtures

private func makeTransaction() -> PurchasedTransaction {
	PurchasedTransaction(id: 1, sku: "credits.20", jwsRepresentation: "jws-blob")
}

private func makeCredential() -> APICredential {
	APICredential(token: "tok", passwordHash: "hash")
}
