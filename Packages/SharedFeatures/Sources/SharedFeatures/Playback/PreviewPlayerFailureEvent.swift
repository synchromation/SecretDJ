/// Fires when a preview's download or decode fails. Unlike
/// ``LikeFailureEvent``/``TuneInToastEvent``, this path never carries server
/// copy — a preview failure is always a client-side transport or decode
/// error, not a server response — so it carries no message at all: the
/// caller shows its own fixed, localized fallback copy every time this
/// changes (mirrors ``TuneInScreenCopy``'s doc comment on why SharedFeatures
/// owns no copy of its own).
public struct PreviewPlayerFailureEvent: Equatable, Sendable {
	/// Increments on every occurrence, so two failures in a row are still
	/// distinct values for a SwiftUI `onChange(of:)` to react to.
	public let id: Int

	public init(id: Int) {
		self.id = id
	}
}
