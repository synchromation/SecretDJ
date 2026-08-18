import Foundation

/// A ``FeedRefreshClock`` fake for tests and previews: `schedule(after:action:)`
/// never fires on its own — call ``advance()`` to fire every currently
/// pending action, awaiting each in turn, as if its duration had elapsed.
@MainActor
public final class ManualFeedRefreshClock: FeedRefreshClock {
	private struct PendingFiring {
		let id = UUID()
		let action: () async -> Void
	}

	/// How many firings are currently pending — a test's way to confirm a
	/// tick was scheduled (or cancelled).
	public var pendingCount: Int {
		pending.count
	}

	/// Every `duration` this clock was asked to schedule, in call order — a
	/// test's way to confirm which cadence ``FeedScreenModel`` chose.
	public private(set) var scheduledDurations: [Duration] = []

	private var pending: [PendingFiring] = []

	public init() {}

	public func schedule(after duration: Duration, action: @escaping () async -> Void) -> FeedRefreshClockToken {
		scheduledDurations.append(duration)

		let firing = PendingFiring(action: action)
		pending.append(firing)

		return FeedRefreshClockToken { [weak self] in
			self?.pending.removeAll { $0.id == firing.id }
		}
	}

	public func advance() async {
		let firing = pending
		pending.removeAll()

		for item in firing {
			await item.action()
		}
	}
}
