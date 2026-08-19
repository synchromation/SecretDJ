import SwiftUI

/// The copy ``MusicSearchScreen`` renders — like `FeedUI/FeedScreenCopy`,
/// this package view owns no copy of its own; callers build every `Text`
/// from their own String Catalog (localization skill) so SharedFeatures
/// stays free of strings.
public struct MusicSearchScreenCopy {
	public let navigationTitle: Text
	public let artistModeLabel: Text
	public let trackModeLabel: Text
	public let searchFieldPlaceholder: Text
	public let emptySystemImage: String
	public let emptyTitle: Text
	public let emptyMessage: Text
	public let errorSystemImage: String
	public let errorTitle: Text
	public let errorMessage: Text
	public let retryTitle: Text

	public init(
		navigationTitle: Text,
		artistModeLabel: Text,
		trackModeLabel: Text,
		searchFieldPlaceholder: Text,
		emptySystemImage: String = "magnifyingglass",
		emptyTitle: Text,
		emptyMessage: Text,
		errorSystemImage: String = "exclamationmark.triangle",
		errorTitle: Text,
		errorMessage: Text,
		retryTitle: Text,
	) {
		self.navigationTitle = navigationTitle
		self.artistModeLabel = artistModeLabel
		self.trackModeLabel = trackModeLabel
		self.searchFieldPlaceholder = searchFieldPlaceholder
		self.emptySystemImage = emptySystemImage
		self.emptyTitle = emptyTitle
		self.emptyMessage = emptyMessage
		self.errorSystemImage = errorSystemImage
		self.errorTitle = errorTitle
		self.errorMessage = errorMessage
		self.retryTitle = retryTitle
	}
}
