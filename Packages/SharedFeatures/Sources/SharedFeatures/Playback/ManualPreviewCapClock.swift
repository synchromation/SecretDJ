import Foundation

/// A ``PreviewCapClock`` fake for tests and previews: `schedule(after:action:)`
/// never fires on its own — call ``fire()`` to fire every currently pending
/// action, as if the 30-second cap had elapsed. Mirrors
/// ``ManualSearchDebounceClock``.
@MainActor
public final class ManualPreviewCapClock: PreviewCapClock {
	private struct PendingFiring {
		let id = UUID()
		let action: () -> Void
	}

	/// How many firings are currently pending — a test's way to confirm the
	/// cap was armed (or disarmed by an intervening ``PreviewPlayerModel/stop()``).
	public var pendingCount: Int {
		pending.count
	}

	private var pending: [PendingFiring] = []

	public init() {}

	public func schedule(after duration: Duration, action: @escaping () -> Void) -> PreviewCapClockToken {
		let firing = PendingFiring(action: action)
		pending.append(firing)

		return PreviewCapClockToken { [weak self] in
			self?.pending.removeAll { $0.id == firing.id }
		}
	}

	/// Fires every pending action, as if its duration had elapsed.
	public func fire() {
		let firing = pending
		pending.removeAll()

		for item in firing {
			item.action()
		}
	}
}
