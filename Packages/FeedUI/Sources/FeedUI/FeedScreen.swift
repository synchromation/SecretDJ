import DesignSystem
import SwiftUI

/// Wraps ``FeedView`` with its screen model: pull-to-refresh, event-driven
/// pagination, and the loading/empty/error state surfaces — the S3.4
/// composition of ``FeedScreenModel`` over the S3.1–S3.3 render/action
/// pieces. Toast presentation and navigation stay with the app: this view
/// only exposes ``onOutcome`` and ``onJukeboxChanged``, never dispatching
/// either itself.
public struct FeedScreen: View {
	public let model: FeedScreenModel
	public let copy: FeedScreenCopy
	/// Called with a tapped cell's routed outcome; `nil` renders every cell
	/// non-interactive.
	public let onOutcome: ((FeedActionOutcome) -> Void)?
	/// Called whenever ``FeedScreenModel/jukeboxChangedEvent`` fires. Showing
	/// a toast and deciding what "reload" means for the app's navigation
	/// stack (LEGACY.md "Change detection") are this closure's job.
	public let onJukeboxChanged: (() -> Void)?
	/// Forwarded to ``FeedView``'s own parameter of the same name — see its
	/// doc comment (PLAN.md S6.9's extra-content ticker). `nil` for every
	/// screen without a ticker.
	public let onScrollDirectionChange: ((FeedScrollDirection) -> Void)?

	public init(
		model: FeedScreenModel,
		copy: FeedScreenCopy,
		onOutcome: ((FeedActionOutcome) -> Void)? = nil,
		onJukeboxChanged: (() -> Void)? = nil,
		onScrollDirectionChange: ((FeedScrollDirection) -> Void)? = nil,
	) {
		self.model = model
		self.copy = copy
		self.onOutcome = onOutcome
		self.onJukeboxChanged = onJukeboxChanged
		self.onScrollDirectionChange = onScrollDirectionChange
	}

	public var body: some View {
		content
			// S9.5: the central place for every backend-driven feed's own
			// screen-level surface — most `FeedScreen` call sites already
			// paint their own outer container with this same role (a
			// header above the feed, an extra bar below it, ...), so this
			// is deliberately harmless to layer under those too, and is
			// what covers the handful of call sites with nothing else to
			// paint it (`DesignSystem/View/themedScreen(_:)`'s doc comment).
			.themedScreen()
			.task { await model.start() }
			.onDisappear { model.stop() }
			.onChange(of: model.jukeboxChangedEvent) { _, newValue in
				guard newValue != nil else { return }
				onJukeboxChanged?()
			}
	}

	@ViewBuilder
	private var content: some View {
		switch model.phase {
		case .loading:
			ProgressSurface(message: copy.loadingMessage)

		case .empty:
			refreshableScroll {
				EmptyStateView(systemImage: copy.emptySystemImage, title: copy.emptyTitle, message: copy.emptyMessage)
			}

		case .error(let offline):
			refreshableScroll {
				ErrorStateView(
					systemImage: offline ? copy.offlineSystemImage : copy.errorSystemImage,
					title: offline ? copy.offlineTitle : copy.errorTitle,
					message: offline ? copy.offlineMessage : copy.errorMessage,
					retryTitle: copy.retryTitle,
					retryAction: { Task { await model.refresh() } },
				)
			}

		case .loaded:
			FeedView(
				sections: model.visibleSections,
				generation: model.generation,
				onItemTap: { item in
					guard let outcome = model.outcome(forTap: item) else { return }
					onOutcome?(outcome)
				},
				onApproachingEnd: { Task { await model.loadNextPage() } },
				onScrollDirectionChange: onScrollDirectionChange,
			)
			.refreshable { await model.refresh() }
		}
	}

	/// `EmptyStateView`/`ErrorStateView` don't fill the screen on their own,
	/// but `.refreshable` needs a scrollable container to attach the
	/// pull-to-refresh gesture to.
	private func refreshableScroll(@ViewBuilder content: () -> some View) -> some View {
		ScrollView {
			content()
				.frame(maxWidth: .infinity)
		}
		.refreshable { await model.refresh() }
	}
}
