import SecretDJAPI
import SecretDJDomain

/// The credits/top-up calls this feature needs, thinned from
/// ``SecretDJAPI/APIClient`` to this feature's exact surface
/// (ios-architecture: a protocol seam per real dependency) — `topupnotify`/
/// `redeemjukeboxvoucher`/`numpaidcredits`, all already built and
/// fixture-tested in S1.3g.
protocol TopUpsServicing: Sendable {
	/// `topupnotify` — submits one purchase/restore confirmation for
	/// server-side verification (`secretdjv3/TopUpAPIAccess.swift`'s
	/// `verifyTransaction`).
	func notifyPurchase(
		userId: String,
		vendor: Vendor,
		action: TopUpNotifyAction,
		transactionId: String,
		receiptBase64: String,
		credential: APICredential,
	) async throws(TopUpsServiceError) -> TopUpNotifyServiceResult

	/// `redeemjukeboxvoucher` — `venueId` is only sent when supplied.
	func redeemVoucher(
		userId: String,
		venueId: String?,
		code: String,
		credential: APICredential,
	) async throws(TopUpsServiceError) -> VoucherRedemptionServiceResult

	/// `numpaidcredits` — the paid-credit count as a display string, shown
	/// after "Restore Purchases" finds nothing to restore.
	func numPaidCredits(
		userId: String,
		credential: APICredential,
	) async throws(TopUpsServiceError) -> NumPaidCreditsServiceResult
}

/// Every way a ``TopUpsServicing`` call can fail — same shape as this app's
/// other feature-scoped service errors (`OnboardingError`), kept as its own
/// type since each feature's seam is deliberately separate.
enum TopUpsServiceError: Error, Equatable {
	case server(message: String?)
	case connection

	init(_ apiError: APIError) {
		if case .server(let message) = apiError {
			self = .server(message: message)
		} else {
			self = .connection
		}
	}
}

/// ``TopUpsServicing/notifyPurchase(userId:vendor:action:transactionId:receiptBase64:credential:)``'s
/// outcome — ``SecretDJAPI/TopUpNotifyOutcome`` reused directly (already the
/// exact classification `topupnotify`'s `ReturnCode` needs), alongside the
/// rotated token every authenticated call may carry.
struct TopUpNotifyServiceResult: Equatable {
	let outcome: TopUpNotifyOutcome
	let rotatedToken: String?
}

/// ``TopUpsServicing/redeemVoucher(userId:venueId:code:credential:)``'s
/// outcome.
struct VoucherRedemptionServiceResult: Equatable {
	let succeeded: Bool
	let message: String?
	let rotatedToken: String?
}

/// ``TopUpsServicing/numPaidCredits(userId:credential:)``'s outcome. Never
/// parsed to `Int` client-side, matching
/// `secretdjv3/TopUpAPIAccess.swift`'s `parseNumPaidCreditsSuccess`.
struct NumPaidCreditsServiceResult: Equatable {
	let text: String?
	let rotatedToken: String?
}
