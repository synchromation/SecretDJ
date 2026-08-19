import DesignSystem
import Observability
import Observation

/// Drives a mood/atmosphere tile tap (LEGACY.md "Change mood (machine
/// control)"): calls ``AtmosphereChanging`` for this screen's venue at a
/// fixed default duration, then shows the server's own confirmation copy as
/// a toast on success (PLAN.md S6.3 scope item 1).
///
/// The full legacy duration-selection panel (`MoodSectionHeaderView`'s
/// hours/minutes slider, server-configured min/max/granularity) is
/// deliberately deferred — this half of S6.3 only wires the tile tap itself
/// through to the server; a picker screen is a natural follow-up once one is
/// scoped.
@MainActor
@Observable
public final class MoodTileModel {
	/// Whether a change is currently in flight — guards
	/// ``changeAtmosphere(itemId:)`` against a second tap racing the first,
	/// and lets the view disable the tapped tile.
	public private(set) var isChanging = false

	private let venueId: String
	private let atmosphereChanging: any AtmosphereChanging
	private let toastQueue: ToastQueue
	private let defaultDurationMinutes: Int
	private let observability: ObservabilityPipeline

	public init(
		venueId: String,
		atmosphereChanging: any AtmosphereChanging,
		toastQueue: ToastQueue,
		defaultDurationMinutes: Int = 30,
		observability: ObservabilityPipeline = .disabled,
	) {
		self.venueId = venueId
		self.atmosphereChanging = atmosphereChanging
		self.toastQueue = toastQueue
		self.defaultDurationMinutes = defaultDurationMinutes
		self.observability = observability
	}

	/// A no-op while ``isChanging`` — the double-tap guard. On success with
	/// server copy, enqueues it verbatim (D11: server copy renders as
	/// delivered, never re-worded client-side); a failure is reported to
	/// observability but shows no toast, since the client owns no fallback
	/// copy of its own to show instead (package views own zero copy).
	public func changeAtmosphere(itemId: Int) async {
		guard !isChanging else { return }

		isChanging = true
		defer { isChanging = false }

		observability.interaction("changeAtmosphere")

		do {
			let result = try await atmosphereChanging.changeAtmosphere(
				itemId: itemId,
				venueId: venueId,
				minutes: defaultDurationMinutes,
			)
			if let message = result.message, !message.isEmpty {
				toastQueue.enqueue(ToastItem(message: message))
			}
			observability.track(MusicSelectionEvent.atmosphereChanged)
		} catch {
			observability.report(error, category: "MusicSelection")
			observability.track(MusicSelectionEvent.atmosphereChangeFailed)
		}
	}
}
