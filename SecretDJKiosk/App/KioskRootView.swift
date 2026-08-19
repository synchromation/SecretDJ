import Observability
import SecretDJAPI
import SwiftUI

/// The kiosk's root gate — the same shape as the consumer app's own
/// `RootView`, minus every consumer-only step: no onboarding, no social
/// account creation (LEGACY.md's kiosk login is "a plain username/password
/// form, no Facebook/Apple sign-in"). No session shows venue sign-in; an
/// existing one shows the (placeholder, until S7.2–S7.5) kiosk home.
///
/// The staff reset gesture (``staffResetOverlay(gestureModel:resetModel:)``)
/// wraps whichever screen is showing, not just one of them — a venue
/// signed into the wrong account needs to reach it from the sign-in screen
/// too, not only once already inside.
struct KioskRootView: View {
	let sessionStore: SessionStore
	let apiClient: APIClient
	let observability: ObservabilityPipeline

	@State private var gestureModel: StaffResetGestureModel
	@State private var resetModel: StaffResetModel

	init(
		sessionStore: SessionStore,
		apiClient: APIClient,
		cacheClearing: [any KioskCacheClearing] = [URLCacheClearing()],
		observability: ObservabilityPipeline = .disabled,
	) {
		self.sessionStore = sessionStore
		self.apiClient = apiClient
		self.observability = observability
		_gestureModel = State(initialValue: StaffResetGestureModel())
		_resetModel = State(initialValue: StaffResetModel(
			sessionStore: sessionStore,
			cacheClearing: cacheClearing,
			observability: observability,
		))
	}

	var body: some View {
		content
			.staffResetOverlay(gestureModel: gestureModel, resetModel: resetModel)
	}

	@ViewBuilder
	private var content: some View {
		if sessionStore.isSignedIn {
			KioskHomeView(sessionStore: sessionStore)
		} else {
			KioskSignInView(model: KioskSignInModel(
				signInService: APIClientKioskSignInService(client: apiClient),
				sessionStore: sessionStore,
				observability: observability,
			))
		}
	}
}
