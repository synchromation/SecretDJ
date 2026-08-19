import Observability
import Observation
import SecretDJAPI

/// Executes the staff reset once ``StaffResetGestureModel`` has fired and
/// the confirmation dialog has been explicitly accepted: signs the session
/// out and runs every registered ``KioskCacheClearing``, then returns —
/// the app's own signed-out gate (``KioskRootView``) takes it back to the
/// venue sign-in screen from there, so there is no `exit(0)`. Legacy's
/// `?RESTART?` handler called `exit(0)` to force a relaunch onto a fresh
/// sign-in; this rewrite reaches the same end state without killing the
/// process (PLAN.md S7.1).
@Observable
final class StaffResetModel {
	private let sessionStore: SessionStore
	private let cacheClearing: [any KioskCacheClearing]
	private let observability: ObservabilityPipeline

	init(
		sessionStore: SessionStore,
		cacheClearing: [any KioskCacheClearing],
		observability: ObservabilityPipeline = .disabled,
	) {
		self.sessionStore = sessionStore
		self.cacheClearing = cacheClearing
		self.observability = observability
	}

	/// Runs the reset. Safe to call again on an already-signed-out session —
	/// caches still get cleared.
	func performReset() {
		observability.interaction("staffReset")

		sessionStore.signOut()
		for clearer in cacheClearing {
			clearer.clear()
		}

		observability.log(.notice, "Staff reset completed", category: "StaffReset")
	}
}
