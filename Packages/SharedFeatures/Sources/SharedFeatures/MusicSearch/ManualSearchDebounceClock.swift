import Foundation

/// A ``SearchDebounceClock`` fake for tests and previews:
/// `schedule(after:action:)` never fires on its own — call ``advance()`` to
/// fire every currently pending action, awaiting each in turn, as if its
/// duration had elapsed. Mirrors `FeedUI/ManualFeedRefreshClock`.
@MainActor
public final class ManualSearchDebounceClock: SearchDebounceClock {
	private struct PendingFiring {
		let id = UUID()
		let action: () async -> Void
	}

	/// How many firings are currently pending — a test's way to confirm a
	/// debounced search was scheduled (or cancelled by a fresher keystroke).
	public var pendingCount: Int {
		pending.count
	}

	private var pending: [PendingFiring] = []

	public init() {}

	public func schedule(after duration: Duration, action: @escaping () async -> Void) -> SearchDebounceClockToken {
		let firing = PendingFiring(action: action)
		pending.append(firing)

		return SearchDebounceClockToken { [weak self] in
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
