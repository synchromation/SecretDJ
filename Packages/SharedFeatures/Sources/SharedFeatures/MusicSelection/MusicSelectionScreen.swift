import DesignSystem
import FeedUI
import Observability
import SecretDJDomain
import SwiftUI

/// One jukebox's paged song catalogue, or the venue's music digest
/// (LEGACY.md "Choosing music: digest → jukebox pages → search") — a thin
/// ``FeedUI/FeedScreen`` wrapper over whichever endpoint the caller's
/// `loader` hits, so this same type serves both `musicselection` (a specific
/// jukebox, `AppDestination.jukebox`) and `musicdigest` (the venue's jukebox
/// wall) without duplicating the paginated-feed plumbing. Both apps use it —
/// `changePolicy` defaults to ``FeedUI/FeedChangeDetector/Policy/surfaceChange``
/// for the consumer; the kiosk passes ``FeedUI/FeedChangeDetector/Policy/reloadInPlace``
/// per PLAN.md S7.4.
///
/// Mood/atmosphere tiles (the `matrixControlLarge` template, rendered by
/// FeedUI's existing `controlTile` cell) ride the same tap path as every
/// other cell: a tap routes to ``FeedUI/FeedActionOutcome/changeAtmosphere(itemId:)``,
/// which this screen intercepts and hands to ``MoodTileModel`` rather than
/// forwarding — no other outcome is this screen's to handle, since it has
/// no venue identity of its own to resolve `showJukebox`/`launchSearch`/
/// `showSongsForArtist` against (the caller's own venue-aware routing does
/// that, exactly as ``FeedUI/FeedScreen`` already leaves navigation to its
/// caller).
public struct MusicSelectionScreen: View {
	public let venueId: String
	public let copy: FeedScreenCopy
	/// Called for every outcome this screen doesn't itself handle
	/// (``FeedUI/FeedActionOutcome/changeAtmosphere(itemId:)`` alone is
	/// self-handled) — the caller resolves navigation with its own venue
	/// context, matching ``FeedUI/FeedScreen/onOutcome``'s own contract.
	public let onOutcome: ((FeedActionOutcome) -> Void)?
	/// Forwarded from ``FeedUI/FeedScreen/onJukeboxChanged`` unmodified —
	/// this package owns no copy to build a toast from, so the caller
	/// decides what "the jukebox changed" means to show (mirrors every
	/// other S6 feed screen's own jukebox-changed handling).
	public let onJukeboxChanged: (() -> Void)?

	@State private var model: FeedScreenModel
	@State private var moodTileModel: MoodTileModel

	public init(
		venueId: String,
		loader: any FeedLoading,
		atmosphereChanging: any AtmosphereChanging,
		toastQueue: ToastQueue,
		copy: FeedScreenCopy,
		changePolicy: FeedChangeDetector.Policy = .surfaceChange,
		installedApps: any InstalledApps = NoInstalledApps(),
		onOutcome: ((FeedActionOutcome) -> Void)? = nil,
		onJukeboxChanged: (() -> Void)? = nil,
		observability: ObservabilityPipeline = .disabled,
	) {
		self.venueId = venueId
		self.copy = copy
		self.onOutcome = onOutcome
		self.onJukeboxChanged = onJukeboxChanged
		_model = State(initialValue: FeedScreenModel(
			loader: loader,
			router: FeedActionRouter(installedApps: installedApps),
			configuration: FeedConfiguration(autoRefresh: nil, paginationEnabled: true, changePolicy: changePolicy),
		))
		_moodTileModel = State(initialValue: MoodTileModel(
			venueId: venueId,
			atmosphereChanging: atmosphereChanging,
			toastQueue: toastQueue,
			observability: observability,
		))
	}

	public var body: some View {
		FeedScreen(model: model, copy: copy, onOutcome: handle(outcome:), onJukeboxChanged: onJukeboxChanged)
			.frame(maxWidth: .infinity, maxHeight: .infinity)
			.background(Theme.ColorRole.background.color)
			.disabled(moodTileModel.isChanging)
			.tracksScreen("MusicSelection")
	}

	private func handle(outcome: FeedActionOutcome) {
		switch outcome {
		case .changeAtmosphere(let itemId):
			Task { await moodTileModel.changeAtmosphere(itemId: itemId) }

		default:
			onOutcome?(outcome)
		}
	}
}

/// The default ``InstalledApps`` for a music-selection feed — its content
/// (songs, jukeboxes, mood tiles) never carries a promotion action, so
/// nothing here ever queries an installed app; callers only override this
/// to inject a test fake.
public struct NoInstalledApps: InstalledApps {
	public init() {}

	public func isInstalled(_: SocialPlatform) -> Bool {
		false
	}
}

// MARK: - Previews

#Preview("Loaded") {
	NavigationStack {
		MusicSelectionScreen(
			venueId: "v1",
			loader: PreviewMusicSelectionLoading.loaded(),
			atmosphereChanging: InMemoryAtmosphereChanging(),
			toastQueue: ToastQueue(),
			copy: .preview,
		)
	}
}

#Preview("Empty") {
	NavigationStack {
		MusicSelectionScreen(
			venueId: "v1",
			loader: PreviewMusicSelectionLoading.empty(),
			atmosphereChanging: InMemoryAtmosphereChanging(),
			toastQueue: ToastQueue(),
			copy: .preview,
		)
	}
}

#Preview("Accessibility text size") {
	NavigationStack {
		MusicSelectionScreen(
			venueId: "v1",
			loader: PreviewMusicSelectionLoading.loaded(),
			atmosphereChanging: InMemoryAtmosphereChanging(),
			toastQueue: ToastQueue(),
			copy: .preview,
		)
	}
	.environment(\.dynamicTypeSize, .accessibility5)
}

extension FeedScreenCopy {
	/// Preview-only placeholder copy — a real app supplies its own
	/// String-Catalog-backed ``FeedUI/FeedScreenCopy`` (this package owns no
	/// copy of its own).
	fileprivate static var preview: FeedScreenCopy {
		FeedScreenCopy(
			emptySystemImage: Theme.Icon.jukebox.systemName,
			emptyTitle: Text(verbatim: "Nothing Here Yet"),
			emptyMessage: Text(verbatim: "This jukebox hasn't got anything to show yet."),
			errorTitle: Text(verbatim: "Something Went Wrong"),
			errorMessage: Text(verbatim: "Sorry, we couldn't load this jukebox."),
			offlineTitle: Text(verbatim: "You're Offline"),
			offlineMessage: Text(verbatim: "Check your connection and try again."),
			retryTitle: Text(verbatim: "Try Again"),
		)
	}
}
