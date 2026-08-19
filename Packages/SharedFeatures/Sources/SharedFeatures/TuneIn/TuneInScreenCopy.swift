import SwiftUI

/// The copy ``TuneInScreen`` renders — like ``MusicSearchScreenCopy``/
/// `FeedUI/FeedScreenCopy`, this package view owns no copy of its own;
/// callers build every `Text` from their own String Catalog (localization
/// skill) so SharedFeatures stays free of strings. Deliberately excludes any
/// out-of-credits funnel copy (the pic-for-credits dialog, top-up routing) —
/// that flow's UI is entirely consumer-owned (``TuneInScreen/onOutOfCredits``'s
/// doc comment), so its copy lives with the consumer app too.
public struct TuneInScreenCopy {
	public let navigationTitle: Text
	public let requestButtonTitle: Text
	public let skipButtonTitle: Text
	public let neverPlayButtonTitle: Text
	public let buzzAccessibilityLabel: Text
	/// The song-preview button's accessible name — constant across both
	/// states, with ``previewPlayingValue``/``previewStoppedValue``
	/// announcing which one currently applies (mirrors ``LikeButton``'s own
	/// label/value split).
	public let previewAccessibilityLabel: Text
	public let previewPlayingValue: Text
	public let previewStoppedValue: Text
	/// Shown when a preview's download or decode fails
	/// (``PreviewPlayerFailureEvent``'s doc comment: this path never carries
	/// server copy, so SharedFeatures needs a caller-supplied fallback for
	/// every occurrence, not only a nil-message one). A plain `String`, not
	/// `Text` — ``DesignSystem/ToastItem/message`` is a `String` (server
	/// toast copy always arrives as one), so the caller builds this with
	/// `String(localized:comment:)` rather than a SwiftUI `Text` literal.
	public let previewFailureMessage: String

	public init(
		navigationTitle: Text,
		requestButtonTitle: Text,
		skipButtonTitle: Text,
		neverPlayButtonTitle: Text,
		buzzAccessibilityLabel: Text,
		previewAccessibilityLabel: Text,
		previewPlayingValue: Text,
		previewStoppedValue: Text,
		previewFailureMessage: String,
	) {
		self.navigationTitle = navigationTitle
		self.requestButtonTitle = requestButtonTitle
		self.skipButtonTitle = skipButtonTitle
		self.neverPlayButtonTitle = neverPlayButtonTitle
		self.buzzAccessibilityLabel = buzzAccessibilityLabel
		self.previewAccessibilityLabel = previewAccessibilityLabel
		self.previewPlayingValue = previewPlayingValue
		self.previewStoppedValue = previewStoppedValue
		self.previewFailureMessage = previewFailureMessage
	}
}
