import DesignSystem
import FeedUI
import Observability
import SecretDJDomain
import SwiftUI

/// A multi-song artist's song list (LEGACY.md "Artist search": "else
/// songs-for-artist feed") — the drill-in `FeedUI/FeedActionOutcome
/// .showSongsForArtist(artist:)` routes to. A thin `FeedUI/FeedScreen`
/// wrapper, same shape as every other S6 feed screen; its own `FeedLoading`
/// is ``MusicSearchingSongsForArtistLoading``, so this screen shares the
/// ``MusicSearching`` seam with the rest of search rather than opening a
/// separate one. `errorRecovery` mirrors ``MusicSelectionScreen``'s own
/// opt-in (`nil` for the consumer; the kiosk arms it, PLAN.md S7.7).
public struct SongsForArtistScreen: View {
	public let copy: FeedScreenCopy
	public let onOutcome: ((FeedActionOutcome) -> Void)?

	@State private var model: FeedScreenModel

	public init(
		artistName: String,
		searching: any MusicSearching,
		copy: FeedScreenCopy,
		errorRecovery: FeedConfiguration.ErrorRecovery? = nil,
		installedApps: any InstalledApps = NoInstalledApps(),
		onOutcome: ((FeedActionOutcome) -> Void)? = nil,
		observability: ObservabilityPipeline = .disabled,
	) {
		self.copy = copy
		self.onOutcome = onOutcome
		_model = State(initialValue: FeedScreenModel(
			loader: MusicSearchingSongsForArtistLoading(searching: searching, artistName: artistName),
			router: FeedActionRouter(installedApps: installedApps),
			configuration: FeedConfiguration(
				autoRefresh: nil,
				paginationEnabled: false,
				changePolicy: .surfaceChange,
				errorRecovery: errorRecovery,
			),
			observability: observability,
		))
	}

	public var body: some View {
		FeedScreen(model: model, copy: copy, onOutcome: onOutcome)
			.frame(maxWidth: .infinity, maxHeight: .infinity)
			.themedScreen()
			.tracksScreen("SongsForArtist")
	}
}

/// The ``FeedUI/FeedLoading`` adapter over ``MusicSearching/songs(forArtist:)``
/// — a single fetch with no pagination concept, so every `page` request
/// (including retries from pull-to-refresh) re-issues the same call.
struct MusicSearchingSongsForArtistLoading: FeedLoading {
	let searching: any MusicSearching
	let artistName: String

	func load(page _: Int?) async throws -> SectionList {
		try await searching.songs(forArtist: artistName)
	}
}

// MARK: - Previews

#Preview("Loaded") {
	NavigationStack {
		SongsForArtistScreen(artistName: "Coldplay", searching: PreviewMusicSearching.tracks(), copy: .preview)
	}
}

#Preview("Accessibility text size") {
	NavigationStack {
		SongsForArtistScreen(artistName: "Coldplay", searching: PreviewMusicSearching.tracks(), copy: .preview)
	}
	.environment(\.dynamicTypeSize, .accessibility5)
}

extension FeedScreenCopy {
	/// Preview-only placeholder copy — a real app supplies its own
	/// String-Catalog-backed ``FeedUI/FeedScreenCopy`` (this package owns no
	/// copy of its own).
	fileprivate static var preview: FeedScreenCopy {
		FeedScreenCopy(
			emptySystemImage: Theme.Icon.song.systemName,
			emptyTitle: Text(verbatim: "No Songs"),
			emptyMessage: Text(verbatim: "This artist has no songs here yet."),
			errorTitle: Text(verbatim: "Something Went Wrong"),
			errorMessage: Text(verbatim: "Sorry, we couldn't load these songs."),
			offlineTitle: Text(verbatim: "You're Offline"),
			offlineMessage: Text(verbatim: "Check your connection and try again."),
			retryTitle: Text(verbatim: "Try Again"),
		)
	}
}
