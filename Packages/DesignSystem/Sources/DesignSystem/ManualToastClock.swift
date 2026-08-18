import Foundation

/// A ``ToastClock`` fake for tests and previews: `schedule(after:action:)`
/// never fires on its own — call ``advance()`` to fire every currently
/// pending action, as if its duration had elapsed.
@MainActor
public final class ManualToastClock: ToastClock {
	private struct PendingFiring {
		let id = UUID()
		let action: () -> Void
	}

	/// How many firings are currently pending — a test's way to confirm a
	/// scheduled dismiss was set (or cancelled).
	public var pendingCount: Int {
		pending.count
	}

	private var pending: [PendingFiring] = []

	public init() {}

	public func schedule(after duration: Duration, action: @escaping () -> Void) -> ToastClockToken {
		let firing = PendingFiring(action: action)
		pending.append(firing)

		return ToastClockToken { [weak self] in
			self?.pending.removeAll { $0.id == firing.id }
		}
	}

	public func advance() {
		let firing = pending
		pending.removeAll()

		for item in firing {
			item.action()
		}
	}
}
