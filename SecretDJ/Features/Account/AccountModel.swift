import Foundation
import Observability
import Observation
import SecretDJAPI

/// Drives account deletion, reached from the signed-in placeholder
/// (`// S6.11:` relocates the entry point into Settings). Sign-out has no
/// branching logic of its own — a single call plus a breadcrumb — so it
/// stays directly on ``SignedInPlaceholderView`` rather than gaining a
/// model (ios-architecture: seams exist per real dependency, not per
/// possibility).
///
/// `credential` is captured at init, like ``OnboardingModel``'s — this
/// model is only ever constructed while signed in (by `RootView`), so it
/// never needs to handle "not signed in mid-flow".
@Observable
final class AccountModel {
	private(set) var isSubmittingDeletion = false
	private(set) var errorMessage: String?
	/// Set once `requestdeleteaccount` has succeeded and the local session
	/// has been wiped. The view swaps to the terminal "deletion requested"
	/// screen — replacing legacy's blocking alert + `exit(0)` — and no
	/// client-side blocked-state flag is persisted anywhere: the server
	/// owns the account's fate, and a fresh sign-in attempt will simply
	/// fail server-side (LEGACY.md's load-bearing-typo section explains why
	/// the legacy `deleteAccountRequested` local flag is deliberately not
	/// ported).
	private(set) var isDeletionRequested = false

	private let personId: String
	private let credential: APICredential
	private let accountService: any AccountServicing
	private let sessionStore: SessionStore
	private let observability: ObservabilityPipeline

	init(
		personId: String,
		credential: APICredential,
		accountService: any AccountServicing,
		sessionStore: SessionStore,
		observability: ObservabilityPipeline = .disabled,
	) {
		self.personId = personId
		self.credential = credential
		self.accountService = accountService
		self.sessionStore = sessionStore
		self.observability = observability
	}

	/// Requests server-side deletion, then wipes the local session on
	/// success. Called only after the view's two confirmation steps; a
	/// no-op once ``isDeletionRequested``, guarding against a duplicate
	/// destructive call (e.g. a second tap before the view updates).
	func requestDeletion() async {
		guard !isDeletionRequested else {
			return
		}

		observability.interaction("requestAccountDeletion")
		isSubmittingDeletion = true
		errorMessage = nil

		do {
			_ = try await accountService.requestDeleteAccount(userId: personId, credential: credential)
			observability.track(AccountEvent.accountDeletionRequested)
			sessionStore.signOut()
			isDeletionRequested = true
		} catch {
			observability.track(AccountEvent.accountDeletionRequestFailed)
			handle(error)
		}

		isSubmittingDeletion = false
	}

	private func handle(_ error: AccountError) {
		observability.report(error, category: "Account")

		switch error {
		case .server(let message):
			errorMessage = message ?? Self.fallbackErrorMessage

		case .connection:
			errorMessage = Self.fallbackErrorMessage
		}
	}

	private static var fallbackErrorMessage: String {
		String(
			localized: "Sorry, we couldn't request that.\n\nPlease check that you have a good connection to your cellular data or WiFi network.",
			comment: "Error shown when requesting account deletion fails, including before reaching the server.",
		)
	}
}
