import Foundation
import Observability
import Observation
import SecretDJAPI

/// Drives Facebook sign-in: the App Tracking Transparency gate
/// (``TrackingAuthorizing``), the Facebook Login SDK flow
/// (``FacebookAuthorizing``), then `facebooksignin` with the day-of-year
/// digest (``SecretDJAPI/FacebookSignInAuthDigest``). Success signs the
/// shared ``SessionStore`` in; failure surfaces a message for the view to
/// show. Mirrors ``AppleSignInModel``'s shape, with the tracking gate ahead
/// of authorization (LEGACY.md "Privacy/tracking": the ATT prompt exists
/// solely to gate Facebook SDK features).
@Observable
final class FacebookSignInModel {
	private(set) var isSigningIn = false
	private(set) var errorMessage: String?
	/// Set once a brand-new account has just been created and signed in via
	/// Facebook. Username isn't this model's job (LEGACY.md "Login, sign-up,
	/// onboarding": Facebook route → username → photo) — the view reacts to
	/// this to route into the Login feature's own username step, then on
	/// into onboarding's `OnboardingRoute.facebook` photo step.
	private(set) var didCreateAccount = false
	private(set) var trackingStatus: TrackingAuthorizationStatus

	private let trackingAuthorizing: any TrackingAuthorizing
	private let facebookAuthorizing: any FacebookAuthorizing
	private let authService: any AuthenticationServicing
	private let sessionStore: SessionStore
	private let observability: ObservabilityPipeline
	private let now: @Sendable () -> Date
	private let calendar: Calendar

	init(
		trackingAuthorizing: any TrackingAuthorizing,
		facebookAuthorizing: any FacebookAuthorizing,
		authService: any AuthenticationServicing,
		sessionStore: SessionStore,
		observability: ObservabilityPipeline = .disabled,
		now: @escaping @Sendable () -> Date = Date.init,
		calendar: Calendar = .current,
	) {
		self.trackingAuthorizing = trackingAuthorizing
		self.facebookAuthorizing = facebookAuthorizing
		self.authService = authService
		self.sessionStore = sessionStore
		self.observability = observability
		self.now = now
		self.calendar = calendar
		trackingStatus = trackingAuthorizing.currentStatus()
	}

	/// Whether the Facebook button should respond to taps — `false` once
	/// tracking has been explicitly rejected (LEGACY.md "Privacy/tracking":
	/// "the button is disabled if tracking was rejected"), or while a
	/// sign-in is already in flight.
	var canSignIn: Bool {
		trackingStatus != .denied && trackingStatus != .restricted && !isSigningIn
	}

	func signInWithFacebook() async {
		guard canSignIn else {
			return
		}

		observability.interaction("signInWithFacebook")
		isSigningIn = true
		errorMessage = nil

		if trackingStatus == .notDetermined {
			trackingStatus = await trackingAuthorizing.requestAuthorization()
			guard trackingStatus != .denied, trackingStatus != .restricted else {
				// legacy: a rejection just disables the button for next time —
				// no toast or dialog (LEGACY.md "Privacy/tracking": both were
				// removed at Apple's insistence during App Store review).
				isSigningIn = false
				return
			}
		}

		let authorization: FacebookAuthorizationResult
		do {
			authorization = try await facebookAuthorizing.requestSignIn()
		} catch {
			handle(error)
			isSigningIn = false
			return
		}

		let digest = FacebookSignInAuthDigest.compute(
			facebookUserId: authorization.facebookUserId,
			date: now(),
			calendar: calendar,
		)

		do {
			let session = try await authService.facebookSignIn(
				facebookUserId: authorization.facebookUserId,
				accessToken: authorization.accessToken,
				auth: digest,
				gender: authorization.gender,
				firstName: authorization.firstName,
				lastName: authorization.lastName,
				email: authorization.email,
			)
			if sessionStore.signIn(from: session) {
				if session.created {
					observability.track(LoginEvent.facebookAccountCreated)
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

	private func handle(_ error: FacebookAuthorizationError) {
		switch error {
		case .cancelled:
			break // legacy: no toast, and nothing to report, for user-cancellation

		case .failed:
			observability.report(error, category: "Login")
			errorMessage = Self.facebookErrorMessage
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
			comment: "Error shown when Facebook sign-in fails before reaching the server (offline, timeout).",
		)
	}

	private static var facebookErrorMessage: String {
		String(
			localized: "Sorry, we couldn't sign you in with Facebook.\n\nPlease try again.",
			comment: "Error shown on the login screen when the Facebook sign-in flow fails for a reason other than the user cancelling it.",
		)
	}
}
