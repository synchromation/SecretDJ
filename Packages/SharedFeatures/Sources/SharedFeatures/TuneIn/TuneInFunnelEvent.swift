/// Fires when ``TuneInScreenModel/requestSong()`` comes back out of credits
/// (LEGACY.md business rule 5, `requestsong` `ReturnCode == -8`). Purely a
/// signal: the app decides what to do with it, since both branches need
/// consumer-only UI this package doesn't own — reusing S4.5's onboarding
/// avatar-picker components when `hasProfilePicture` is `false`, or routing
/// to the top-ups screen (`AppDestination.topUps`) either way.
public struct TuneInFunnelEvent: Equatable, Sendable {
	/// Increments on every occurrence, so two out-of-credits requests in a
	/// row are still distinct values for a SwiftUI `onChange(of:)` to react
	/// to.
	public let id: Int
	/// The response's `ImageSize > 0` — whether the signed-in user already
	/// has a profile picture. `false` offers the pic-for-credits upsell;
	/// `true` (or a declined upsell) goes straight to the top-up screen.
	public let hasProfilePicture: Bool

	public init(id: Int, hasProfilePicture: Bool) {
		self.id = id
		self.hasProfilePicture = hasProfilePicture
	}
}
