import SwiftUI

extension EnvironmentValues {
	/// The idle/attract countdown pair for whatever ``AttractIdleContainerView``
	/// currently wraps — `nil` until that container injects a real instance,
	/// which every production screen tree gets (a preview that skips the
	/// container, or a unit test, reads `nil` and simply never reacts to
	/// idle timeouts). Mirrors the ``kioskSkin`` environment value's own
	/// "ambient dependency any descendant screen can read" shape: this is
	/// how ``KioskHomeView`` learns to pop its `NavigationStack` back to
	/// root (``IdleTimerModel/idleTimeoutFireCount``'s own doc comment)
	/// without ``AttractIdleContainerView`` having to know anything about
	/// navigation, and without threading a callback through its generic
	/// `Content` builder.
	@Entry var idleTimerModel: IdleTimerModel?
}
