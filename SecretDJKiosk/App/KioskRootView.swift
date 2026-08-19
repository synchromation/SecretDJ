import Observability
import SecretDJAPI
import SwiftUI

/// The kiosk's root gate — the same shape as the consumer app's own
/// `RootView`, minus every consumer-only step: no onboarding, no social
/// account creation (LEGACY.md's kiosk login is "a plain username/password
/// form, no Facebook/Apple sign-in"). No session shows venue sign-in; a
/// signed-in session with its venue skin not yet ready shows S7.2's
/// download/progress/retry gate (``KioskSkinGateView``); only once that
/// skin is ready does the kiosk home show (placeholder until S7.3+).
///
/// The staff reset gesture (``staffResetOverlay(gestureModel:resetModel:)``)
/// wraps whichever screen is showing, not just one of them — a venue
/// signed into the wrong account needs to reach it from the sign-in screen
/// too, not only once already inside.
struct KioskRootView: View {
	let sessionStore: SessionStore
	let apiClient: APIClient
	let observability: ObservabilityPipeline

	private let skinStoring: any SkinStoring

	@State private var gestureModel: StaffResetGestureModel
	@State private var resetModel: StaffResetModel

	init(
		sessionStore: SessionStore,
		apiClient: APIClient,
		cacheClearing: [any KioskCacheClearing] = [URLCacheClearing()],
		skinStoring: any SkinStoring = FileManagerSkinStoring(),
		observability: ObservabilityPipeline = .disabled,
	) {
		self.sessionStore = sessionStore
		self.apiClient = apiClient
		self.skinStoring = skinStoring
		self.observability = observability
		_gestureModel = State(initialValue: StaffResetGestureModel())
		// Additive per KioskCacheClearing's own doc comment: the skin
		// system's cache-clearer joins whatever the caller passed (or the
		// URLCache default) rather than replacing it, so a caller
		// overriding `cacheClearing` for a test still gets the skin cleared
		// on reset too.
		_resetModel = State(initialValue: StaffResetModel(
			sessionStore: sessionStore,
			cacheClearing: cacheClearing + [SkinCacheClearing(storing: skinStoring)],
			observability: observability,
		))
	}

	var body: some View {
		content
			.staffResetOverlay(gestureModel: gestureModel, resetModel: resetModel)
	}

	@ViewBuilder
	private var content: some View {
		// `venue` is always present once signed in for a kiosk session
		// (``SessionStore/signIn(from:passwordHash:)``'s doc comment: the
		// server always pins one) — the `let` guard is defensive, not a
		// real third state; it falls back to sign-in rather than crashing.
		if sessionStore.isSignedIn, let venue = sessionStore.venue {
			KioskSkinGateView(
				venueId: venue.venueId,
				apiClient: apiClient,
				sessionStore: sessionStore,
				skinStoring: skinStoring,
				observability: observability,
			)
		} else {
			KioskSignInView(model: KioskSignInModel(
				signInService: APIClientKioskSignInService(client: apiClient),
				sessionStore: sessionStore,
				observability: observability,
			))
		}
	}
}
