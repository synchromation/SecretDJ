import Observability
import SecretDJAPI
import SwiftUI

/// The app's root: gates on whether a session was restored at launch — no
/// session shows the login flow, an existing one shows a placeholder for
/// the signed-in state (S5 replaces this with the real three-tab shell).
struct RootView: View {
	let sessionStore: SessionStore
	let apiClient: APIClient
	let observability: ObservabilityPipeline

	var body: some View {
		if sessionStore.isSignedIn {
			SignedInPlaceholderView(sessionStore: sessionStore)
		} else {
			LoginFlow(
				authService: APIClientAuthenticationService(client: apiClient),
				sessionStore: sessionStore,
				observability: observability,
			)
		}
	}
}
