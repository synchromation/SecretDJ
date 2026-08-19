import SecretDJAPI
import SecretDJDomain

/// What ``TopUpNotifySubmitter/submit(_:action:userId:credential:)`` decided
/// — ``SecretDJAPI/TopUpNotifyOutcome`` collapsed to the two things that
/// matter to a caller: what to show, and whether the transaction finished.
enum TopUpNotifySubmissionOutcome: Equatable {
	/// `ReturnCode == 0` — the transaction finished.
	case credited(message: String)
	/// `ReturnCode == 1` — an earlier submission already verified this
	/// transaction; it finished all the same.
	case alreadyProcessed(message: String)
	/// `ReturnCode < 0` — safe to resubmit; the transaction was left
	/// unfinished on purpose.
	case retryable
	/// Any other positive `ReturnCode`, or the service call itself failing
	/// (network/server error) — also left unfinished. Payment already
	/// succeeded by this point (StoreKit's `purchase()` already returned),
	/// so a caller must never pair this with the "No payment was taken."
	/// phrase.
	case failed(message: String)
}

/// ``TopUpNotifySubmitter/submit(_:action:userId:credential:)``'s result.
struct TopUpNotifySubmissionResult: Equatable {
	let outcome: TopUpNotifySubmissionOutcome
	let rotatedToken: String?
}

/// Submits one purchased/restored transaction to `topupnotify` and decides
/// whether to finish it, replacing legacy's finish-before-verify ordering
/// (`secretdjv3/IAPManager.swift`'s `paymentQueue(_:updatedTransactions:)`
/// calls `SKPaymentQueue.default().finishTransaction` unconditionally, before
/// the server call even starts) with StoreKit 2's own durable
/// unfinished-transaction queue as the safety net, in place of legacy's
/// `UserDefaults`-backed `PendingTopUps`: only `credited`/`alreadyProcessed`
/// finish the transaction (`secretdjv3/TopUpAPIAccess.swift`'s
/// `parseTopUpPaymentSuccess` return-code contract) — `retryable` and a hard
/// `failure` both leave it unfinished, so
/// ``ProductPurchasing/unfinishedTransactions()`` keeps surfacing it until
/// the server accepts it. Shared by ``TopUpPurchaseModel`` (a fresh
/// purchase) and ``TopUpTransactionListener`` (startup drain and restore)
/// so the finish/no-finish decision lives in exactly one place.
struct TopUpNotifySubmitter {
	let purchasing: any ProductPurchasing
	let servicing: any TopUpsServicing

	func submit(
		_ transaction: PurchasedTransaction,
		action: TopUpNotifyAction,
		userId: String,
		credential: APICredential,
	) async -> TopUpNotifySubmissionResult {
		let result: TopUpNotifyServiceResult
		do {
			result = try await servicing.notifyPurchase(
				userId: userId,
				vendor: .appleAppStore,
				action: action,
				transactionId: String(transaction.id),
				receiptBase64: transaction.jwsRepresentation,
				credential: credential,
			)
		} catch {
			// StoreKit's own durable unfinished-transaction queue is the
			// safety net now (unlike legacy's hand-rolled retry/expiry
			// machinery) — a transport/server error here is always safe to
			// leave for a later drain to retry.
			return TopUpNotifySubmissionResult(outcome: .retryable, rotatedToken: nil)
		}

		switch result.outcome {
		case .credited(let message):
			await purchasing.finish(transaction)
			return TopUpNotifySubmissionResult(outcome: .credited(message: message), rotatedToken: result.rotatedToken)

		case .alreadyProcessed(let message):
			await purchasing.finish(transaction)
			return TopUpNotifySubmissionResult(
				outcome: .alreadyProcessed(message: message),
				rotatedToken: result.rotatedToken,
			)

		case .retryable:
			return TopUpNotifySubmissionResult(outcome: .retryable, rotatedToken: result.rotatedToken)

		case .failure(let message):
			return TopUpNotifySubmissionResult(outcome: .failed(message: message), rotatedToken: result.rotatedToken)
		}
	}
}
