import DesignSystem
import FeedUI
import Observability
import SecretDJDomain
import SwiftUI

/// Artist/track search (LEGACY.md "Choosing music: digest → jukebox pages →
/// search" → "Search"; PLAN.md S6.3 scope item 2) — a mode picker and search
/// field over ``SearchModel``, rendering results through ``FeedUI/FeedView``
/// with a `DesignSystem/SectionIndexStrip` A–Z rail in artist mode. Both
/// apps use it (the kiosk reuses it at PLAN.md S7.6, at iPad scale).
public struct MusicSearchScreen: View {
	public let copy: MusicSearchScreenCopy
	/// Called for every routed result tap — the caller resolves navigation
	/// with its own venue context (mirrors ``MusicSelectionScreen/onOutcome``'s
	/// contract; this screen has no venue identity of its own).
	public let onOutcome: ((FeedActionOutcome) -> Void)?

	@State private var model: SearchModel
	@State private var scrollRequest: String?
	private let router: FeedActionRouter

	public init(
		searching: any MusicSearching,
		copy: MusicSearchScreenCopy,
		initialMode: MusicSearchMode = .artist,
		installedApps: any InstalledApps = NoInstalledApps(),
		clock: any SearchDebounceClock = SystemSearchDebounceClock(),
		onOutcome: ((FeedActionOutcome) -> Void)? = nil,
		observability: ObservabilityPipeline = .disabled,
	) {
		self.copy = copy
		self.onOutcome = onOutcome
		router = FeedActionRouter(installedApps: installedApps)
		_model = State(initialValue: SearchModel(
			searching: searching,
			mode: initialMode,
			clock: clock,
			observability: observability,
		))
	}

	public var body: some View {
		VStack(spacing: 0) {
			modePicker
			searchField
			content
		}
		.frame(maxWidth: .infinity, maxHeight: .infinity)
		.background(Theme.ColorRole.background.color)
		.navigationTitle(copy.navigationTitle)
		.task { await model.updateMode(model.mode) }
		.tracksScreen("MusicSearch")
	}

	private var modePicker: some View {
		Picker(
			selection: Binding(get: { model.mode }, set: { newMode in Task { await model.updateMode(newMode) } }),
		) {
			copy.artistModeLabel.tag(MusicSearchMode.artist)
			copy.trackModeLabel.tag(MusicSearchMode.track)
		} label: {
			EmptyView()
		}
		.pickerStyle(.segmented)
		.padding(.horizontal, Spacing.medium)
		.padding(.top, Spacing.small)
	}

	private var searchField: some View {
		TextField(text: Binding(get: { model.query }, set: model.updateQuery)) {
			copy.searchFieldPlaceholder
		}
		.textFieldStyle(.roundedBorder)
		.autocorrectionDisabled()
		#if os(iOS)
			.textInputAutocapitalization(.never)
		#endif
			.padding(.horizontal, Spacing.medium)
			.padding(.vertical, Spacing.small)
	}

	@ViewBuilder
	private var content: some View {
		switch model.phase {
		case .idle:
			Spacer(minLength: 0)

		case .searching:
			ProgressSurface()

		case .empty:
			EmptyStateView(systemImage: copy.emptySystemImage, title: copy.emptyTitle, message: copy.emptyMessage)

		case .error:
			ErrorStateView(
				systemImage: copy.errorSystemImage,
				title: copy.errorTitle,
				message: copy.errorMessage,
				retryTitle: copy.retryTitle,
				retryAction: { Task { await retry() } },
			)

		case .loaded:
			resultsView
		}
	}

	private var resultsView: some View {
		HStack(spacing: 0) {
			FeedView(
				sections: model.results,
				generation: 0,
				onItemTap: handle(tap:),
				scrollRequest: model.mode == .artist ? $scrollRequest : nil,
			)

			if model.mode == .artist, !model.indexLetters.isEmpty {
				SectionIndexStrip(letters: model.indexLetters, onSelect: jump(toLetter:))
			}
		}
	}

	private func handle(tap item: FeedDisplayItem) {
		guard let outcome = router.outcome(forTap: item) else { return }
		onOutcome?(outcome)
	}

	private func jump(toLetter letter: String) {
		guard let section = model.results.first(where: { $0.title == letter }) else { return }
		scrollRequest = section.id
	}

	private func retry() async {
		switch model.mode {
		case .artist:
			await model.updateMode(.artist)

		case .track:
			model.updateQuery(model.query)
		}
	}
}

// MARK: - Previews

#Preview("Artist mode") {
	NavigationStack {
		MusicSearchScreen(searching: PreviewMusicSearching.artists(), copy: .preview)
	}
}

#Preview("Track mode") {
	NavigationStack {
		MusicSearchScreen(searching: PreviewMusicSearching.tracks(), copy: .preview, initialMode: .track)
	}
}

#Preview("Accessibility text size") {
	NavigationStack {
		MusicSearchScreen(searching: PreviewMusicSearching.artists(), copy: .preview)
	}
	.environment(\.dynamicTypeSize, .accessibility5)
}

extension MusicSearchScreenCopy {
	/// Preview-only placeholder copy — a real app supplies its own
	/// String-Catalog-backed ``MusicSearchScreenCopy`` (this package owns no
	/// copy of its own).
	fileprivate static var preview: MusicSearchScreenCopy {
		MusicSearchScreenCopy(
			navigationTitle: Text(verbatim: "Search"),
			artistModeLabel: Text(verbatim: "Artists"),
			trackModeLabel: Text(verbatim: "Songs"),
			searchFieldPlaceholder: Text(verbatim: "Search"),
			emptyTitle: Text(verbatim: "No Results"),
			emptyMessage: Text(verbatim: "Try a different search."),
			errorTitle: Text(verbatim: "Something Went Wrong"),
			errorMessage: Text(verbatim: "Sorry, we couldn't search right now."),
			retryTitle: Text(verbatim: "Try Again"),
		)
	}
}
