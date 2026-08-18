import SwiftUI

/// The copy ``FeedScreen`` renders into DesignSystem's state surfaces.
/// Carries no copy of its own beyond this struct's fields — like
/// `EmptyStateView`/`ErrorStateView`, callers build every `Text` from their
/// own String Catalog (localization skill) so FeedUI stays free of strings.
public struct FeedScreenCopy {
	public let loadingMessage: Text?
	public let emptySystemImage: String
	public let emptyTitle: Text
	public let emptyMessage: Text
	public let errorSystemImage: String
	public let errorTitle: Text
	public let errorMessage: Text
	/// Shown instead of the generic error copy when ``FeedLoadPhase/error(offline:)``
	/// carries `offline: true`.
	public let offlineSystemImage: String
	public let offlineTitle: Text
	public let offlineMessage: Text
	public let retryTitle: Text

	public init(
		loadingMessage: Text? = nil,
		emptySystemImage: String,
		emptyTitle: Text,
		emptyMessage: Text,
		errorSystemImage: String = "exclamationmark.triangle",
		errorTitle: Text,
		errorMessage: Text,
		offlineSystemImage: String = "wifi.slash",
		offlineTitle: Text,
		offlineMessage: Text,
		retryTitle: Text,
	) {
		self.loadingMessage = loadingMessage
		self.emptySystemImage = emptySystemImage
		self.emptyTitle = emptyTitle
		self.emptyMessage = emptyMessage
		self.errorSystemImage = errorSystemImage
		self.errorTitle = errorTitle
		self.errorMessage = errorMessage
		self.offlineSystemImage = offlineSystemImage
		self.offlineTitle = offlineTitle
		self.offlineMessage = offlineMessage
		self.retryTitle = retryTitle
	}
}
