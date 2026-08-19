import Observability
import Observation

/// The kiosk's attract/idle countdown pair (PLAN.md S7.3) — a from-scratch
/// port of `secretdjv3/KioskTimer.swift`'s two one-shot timers, kept to the
/// exact semantics legacy proved out over its life on real venue hardware:
///
/// - **Two independent one-shot countdowns**, both configured from
///   ``KioskBehavioralConfig`` (`attractTimeoutSeconds`/`idleTimeoutSeconds`)
///   and both restarted together — at full duration, never a resumed
///   remainder — by ``recordInteraction()`` and by ``setPreviewPlaying(_:)``
///   turning playback off (`KioskTimer.swift`'s `startTimers()`: every
///   restart cancels whatever was pending and reschedules both from zero).
/// - **Suspended, not paused-and-resumed, while a preview plays**:
///   ``setPreviewPlaying(true)`` cancels both countdowns outright and
///   arms neither until told otherwise (`isMusicPlaying` guard in
///   `startTimers()`) — there is no partial credit for time already
///   elapsed before playback started.
/// - **No attract URL, no attract countdown**: when
///   ``KioskBehavioralConfig/attractURL`` is `nil` the attract timer is
///   simply never armed; the idle countdown still runs on its own
///   (S7.3's own scope note — legacy has no such case since every venue
///   skin sets one).
/// - **The idle countdown is inert while the attract screen is showing**:
///   mirrors `KioskNowPlayingViewController.didExceedIdleTimeout`'s own
///   `if isShowingAttract { return }` guard, so an idle timeout that lands
///   after attract has already taken over doesn't also try to reset
///   navigation underneath it.
/// - **Dismissing attract is itself an interaction**: ``recordInteraction()``
///   both ends attract mode and restarts both countdowns in the same call,
///   mirroring legacy's two independent effects of one tap — the attract
///   view's own dismiss button, and `KioskApplication`'s global touch
///   broadcast that also reaches `KioskTimer` — collapsed into one call
///   here since S7.3 has no UIApplication-subclass touch broadcast to fan
///   the same tap out to two listeners (see ``recordInteraction()``'s own
///   doc comment for why).
///
/// Per-touch resets are deliberately **not** breadcrumbed (every tap during
/// normal browsing would call ``recordInteraction()`` — logging each one
/// would flood the pipeline for no diagnostic value); attract showing and
/// being dismissed are rare, meaningful moments and are.
@Observable
final class IdleTimerModel {
	/// Whether the attract screen should be showing — the wiring overlay
	/// (``attractIdleOverlay(model:attractURL:)``) reads this directly to
	/// decide whether to present ``AttractScreen``.
	private(set) var isShowingAttract = false

	/// Increments every time the idle countdown fires while attract isn't
	/// showing — the documented hook S7.4+'s screens will observe
	/// (`.onChange`) to pop back to the jukebox wall and restore the
	/// now-playing header, mirroring legacy's `popToRoot()`
	/// (`KioskNowPlayingViewController.didExceedIdleTimeout`). The kiosk
	/// home is still S7.1's placeholder with nothing to reset yet, so
	/// nothing consumes this today.
	private(set) var idleTimeoutFireCount = 0

	private let attractTimeoutSeconds: Int
	private let idleTimeoutSeconds: Int
	private let hasAttractURL: Bool
	private let clock: any IdleTimerClock
	private let observability: ObservabilityPipeline

	private var attractToken: IdleTimerClockToken?
	private var idleToken: IdleTimerClockToken?
	private var isPreviewPlaying = false

	init(
		config: KioskBehavioralConfig,
		clock: any IdleTimerClock = SystemIdleTimerClock(),
		observability: ObservabilityPipeline = .disabled,
	) {
		attractTimeoutSeconds = config.attractTimeoutSeconds
		idleTimeoutSeconds = config.idleTimeoutSeconds
		hasAttractURL = config.attractURL != nil
		self.clock = clock
		self.observability = observability
		rescheduleTimers()
	}

	/// Call for any user interaction with the kiosk (a scene-level touch —
	/// see ``attractIdleOverlay(model:attractURL:)``, or the attract
	/// screen's own dismiss affordance). Ends attract mode if it was
	/// showing, then restarts both countdowns at full duration — legacy's
	/// `KioskApplication.sendEvent` touch broadcast reset `KioskTimer`
	/// *and*, separately, a tap on `AttractViewController`'s own dismiss
	/// button called `dismiss(animated:)`; S7.3 has no app-wide touch
	/// broadcast to replay that fan-out, so this one call does both.
	func recordInteraction() {
		if isShowingAttract {
			isShowingAttract = false
			observability.interaction("attractDismissed")
		}

		rescheduleTimers()
	}

	/// Call whenever the shared preview player's `isPlaying` changes
	/// (`SharedFeatures/PreviewPlayerModel`'s own doc comment: "S7.3...
	/// observes this property"). `true` suspends both countdowns outright;
	/// `false` restarts both at full duration — never a resumed remainder
	/// (see this type's own doc comment). A no-op when `isPlaying` already
	/// matches the current suspension state.
	func setPreviewPlaying(_ isPlaying: Bool) {
		guard isPlaying != isPreviewPlaying else { return }

		isPreviewPlaying = isPlaying
		rescheduleTimers()
	}

	private func rescheduleTimers() {
		attractToken?.cancel()
		idleToken?.cancel()
		attractToken = nil
		idleToken = nil

		guard !isPreviewPlaying else { return }

		if hasAttractURL {
			attractToken = clock.schedule(after: .seconds(attractTimeoutSeconds)) { [weak self] in
				self?.attractTimerFired()
			}
		}
		idleToken = clock.schedule(after: .seconds(idleTimeoutSeconds)) { [weak self] in
			self?.idleTimerFired()
		}
	}

	private func attractTimerFired() {
		isShowingAttract = true
		observability.interaction("attractShown")
	}

	private func idleTimerFired() {
		guard !isShowingAttract else { return }

		idleTimeoutFireCount += 1
	}
}
