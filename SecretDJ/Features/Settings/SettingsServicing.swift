import Foundation
import SecretDJAPI
import SecretDJDomain

/// The `setuserdetails`/`userdetails` calls Settings' change-details and
/// change-password forms need, thinned from ``SecretDJAPI/APIClient`` to
/// this feature's exact surface (ios-architecture: a protocol seam per real
/// dependency). Gender changes reuse ``OnboardingServicing/setGender(userId:gender:credential:)``
/// directly instead of a third method here — that seam already models
/// `setuserdetails` for gender, so duplicating it under a second protocol
/// would give the same endpoint two seams (see ``ChangeGenderModel``'s doc
/// comment for the full justification).
protocol SettingsServicing: Sendable {
	/// `userdetails` — Settings' change-details form prefills from this,
	/// exactly as the refactor branch's SwiftUI pilot did
	/// (`secretdjv3/SwiftUI/Settings/ChangeDetailsScreen.swift`'s `load()`).
	///
	/// // S1.3: ``SecretDJDomain/Person/email``/``SecretDJDomain/Person/firstName``/
	/// ``SecretDJDomain/Person/lastName`` always decode `nil` today (a known,
	/// separately tracked gap — see their own doc comments); until that
	/// closes, ``ChangeDetailsModel/load()`` prefills those three fields
	/// empty. Not this task's gap to close.
	func fetchDetails(userId: String, credential: APICredential) async throws(SettingsError) -> Person

	/// `setuserdetails` with first/last/screen name/email — Settings' change-
	/// details form.
	func changeDetails(
		userId: String,
		firstName: String,
		lastName: String,
		screenName: String,
		email: String,
		credential: APICredential,
	) async throws(SettingsError) -> SettingsUpdateOutcome

	/// `setuserdetails` with just the new password's SHA-1 hash — Settings'
	/// change-password form. The *current* password is never sent; it's
	/// checked locally against ``SecretDJAPI/APICredential/passwordHash``
	/// (``ChangePasswordModel``'s doc comment), matching
	/// `secretdjv3/SwiftUI/Settings/ChangePasswordScreen.swift`'s own
	/// `ProfileDetailsValidator`-against-`UserManager.password` check.
	func changePassword(
		userId: String,
		newPasswordHash: String,
		credential: APICredential,
	) async throws(SettingsError) -> SettingsUpdateOutcome
}

/// Every way a ``SettingsServicing`` call can fail — same shape as
/// ``OnboardingError``/``AccountError``, kept as its own type since each
/// feature's seam is deliberately separate.
enum SettingsError: Error, Equatable {
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

/// ``SettingsServicing/changeDetails(userId:firstName:lastName:screenName:email:credential:)``/
/// ``SettingsServicing/changePassword(userId:newPasswordHash:credential:)``'s
/// outcome — `setuserdetails`'s `ReturnCode`/`Message` envelope
/// (LEGACY.md's catalog: "`ReturnCode` == 0"), plus a rotated token when the
/// response carried one.
struct SettingsUpdateOutcome: Equatable {
	let succeeded: Bool
	let message: String?
	let rotatedToken: String?
}
