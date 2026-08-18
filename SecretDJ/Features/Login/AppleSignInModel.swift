import Foundation
import Observability
import Observation
import SecretDJAPI

/// Drives Sign in with Apple: the system authorization flow
/// (``AppleAuthorizing``), then `applesignin` with the day-of-year digest
/// (``SecretDJAPI/AppleSignInAuthDigest``) and the name/email Apple only ever
/// supplies once (cached in ``AppleUserInfoStoring``). Success signs the
/// shared ``SessionStore`` in; failure surfaces a message for the view to
/// show.
@Observable
final class AppleSignInModel {
	private(set) var isSigningIn = false
	private(set) var errorMessage: String?
	/// Set once a brand-new account has just been created and signed in via
	/// Apple. Username isn't this model's job (LEGACY.md "Login, sign-up,
	/// onboarding": Apple route → username → gender → photo) — the view
	/// reacts to this to route into the Login feature's own username step,
	/// then on into onboarding's `OnboardingRoute.apple` gender/photo steps.
	private(set) var didCreateAccount = false

	private let appleAuthorizing: any AppleAuthorizing
	private let appleUserInfoStore: any AppleUserInfoStoring
	private let authService: any AuthenticationServicing
	private let sessionStore: SessionStore
	private let observability: ObservabilityPipeline
	private let now: @Sendable () -> Date
	private let calendar: Calendar

	init(
		appleAuthorizing: any AppleAuthorizing,
		appleUserInfoStore: any AppleUserInfoStoring,
		authService: any AuthenticationServicing,
		sessionStore: SessionStore,
		observability: ObservabilityPipeline = .disabled,
		now: @escaping @Sendable () -> Date = Date.init,
		calendar: Calendar = .current,
	) {
		self.appleAuthorizing = appleAuthorizing
		self.appleUserInfoStore = appleUserInfoStore
		self.authService = authService
		self.sessionStore = sessionStore
		self.observability = observability
		self.now = now
		self.calendar = calendar
	}

	func signInWithApple() async {
		observability.interaction("signInWithApple")
		isSigningIn = true
		errorMessage = nil

		let authorization: AppleAuthorizationResult
		do {
			authorization = try await appleAuthorizing.requestSignIn()
		} catch {
			handle(error)
			isSigningIn = false
			return
		}

		let userInfo = resolvedUserInfo(from: authorization)
		let digest = AppleSignInAuthDigest.compute(
			appleUserId: authorization.userId,
			date: now(),
			calendar: calendar,
		)

		do {
			let session = try await authService.appleSignIn(
				appleUserId: authorization.userId,
				auth: digest,
				firstName: userInfo?.firstName,
				lastName: userInfo?.lastName,
				email: userInfo?.email,
			)
			if sessionStore.signIn(from: session) {
				if session.created {
					observability.track(LoginEvent.appleAccountCreated)
					didCreateAccount = true
				}
			} else {
				handle(.connection)
			}
		} catch {
			handle(error)
		}

		isSigningIn = false
	}

	/// Caches `authorization`'s name/email when Apple supplied them (only
	/// ever true on this account's first authorization for this app), else
	/// recovers them from the keychain cache so a returning user's
	/// `applesignin` call still carries them if this is in fact still their
	/// first-ever account creation attempt (e.g. a prior attempt cached them
	/// but failed before completing). Returns `nil` firstName/lastName/email
	/// when neither source has them — callers must not synthesize partial
	/// data (`applesignin`'s all-or-nothing contract).
	private func resolvedUserInfo(from authorization: AppleAuthorizationResult) -> AppleUserInfo? {
		if let firstName = authorization.firstName,
		   let lastName = authorization.lastName,
		   let email = authorization.email
		{
			let info = AppleUserInfo(
				appleUserId: authorization.userId,
				firstName: firstName,
				lastName: lastName,
				email: email,
			)
			appleUserInfoStore.save(info)
			return info
		}

		return appleUserInfoStore.savedUserInfo()
	}

	private func handle(_ error: AppleAuthorizationError) {
		switch error {
		case .cancelled:
			break // legacy: no toast, and nothing to report, for user-cancellation

		case .failed:
			observability.report(error, category: "Login")
			errorMessage = Self.appleErrorMessage
		}
	}

	private func handle(_ error: AuthenticationError) {
		observability.report(error, category: "Login")

		switch error {
		case .server(let message):
			errorMessage = message ?? Self.connectionErrorMessage

		case .connection:
			errorMessage = Self.connectionErrorMessage
		}
	}

	private static var connectionErrorMessage: String {
		String(
			localized: "Sorry, we couldn't sign you in.\n\nPlease check that you have a good connection to your cellular data or WiFi network.",
			comment: "Error shown when native sign-in fails before reaching the server (offline, timeout).",
		)
	}

	private static var appleErrorMessage: String {
		String(
			localized: "Sorry, we couldn't sign you in with Apple.\n\nPlease try again.",
			comment: "Error shown when the Sign in with Apple system flow fails for a reason other than cancellation.",
		)
	}
}
