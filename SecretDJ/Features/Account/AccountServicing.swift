import Foundation
import SecretDJAPI

/// The account-deletion call ``AccountModel`` needs, thinned from
/// ``SecretDJAPI/APIClient`` to this feature's exact surface
/// (ios-architecture: a protocol seam per real dependency).
protocol AccountServicing: Sendable {
	/// `requestdeleteaccount` — marks the account REQUESTED for deletion
	/// server-side (LEGACY.md: the account is deleted asynchronously,
	/// inferred); ``AccountModel`` wipes the local session once this
	/// succeeds.
	func requestDeleteAccount(
		userId: String,
		credential: APICredential,
	) async throws(AccountError) -> AccountDeletionOutcome
}

/// Every way an ``AccountServicing`` call can fail — same shape as
/// ``OnboardingError``/``AuthenticationError``, kept as its own type since
/// each feature's seam is deliberately separate.
enum AccountError: Error, Equatable {
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

/// ``AccountServicing/requestDeleteAccount(userId:credential:)``'s outcome.
struct AccountDeletionOutcome: Equatable {
	/// The server's confirmation copy, when present.
	///
	/// // LIVE-CAPTURE: no legacy fixture exists for this endpoint at all;
	/// the exact copy is unconfirmed, so ``AccountModel`` doesn't surface it
	/// verbatim — see ``AccountDeletionRequestedView``'s doc comment.
	let message: String?
}
