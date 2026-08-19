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

	public init(
		navigationTitle: Text,
		requestButtonTitle: Text,
		skipButtonTitle: Text,
		neverPlayButtonTitle: Text,
		buzzAccessibilityLabel: Text,
	) {
		self.navigationTitle = navigationTitle
		self.requestButtonTitle = requestButtonTitle
		self.skipButtonTitle = skipButtonTitle
		self.neverPlayButtonTitle = neverPlayButtonTitle
		self.buzzAccessibilityLabel = buzzAccessibilityLabel
	}
}
