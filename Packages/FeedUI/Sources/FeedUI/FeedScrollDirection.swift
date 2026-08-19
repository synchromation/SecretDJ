import CoreGraphics

/// A coarse, event-driven scroll direction for the extra-content ticker
/// (PLAN.md S6.9; D9 "keep the legacy scroll-direction show/hide behavior
/// verbatim"). Mirrors `secretdjv3/FeedViewController.swift`'s
/// `scrollViewDidScroll`:
///
/// ```swift
/// let translation = scrollView.panGestureRecognizer.translation(in: scrollView.superview)
/// extraContentManager?.animateIsShowing(translation.y > 0)
/// ```
///
/// `translation.y` there is the pan gesture's *finger* displacement, not
/// the content offset — dragging the finger down (`translation.y > 0`)
/// moves the visible content toward the *start* of the feed, i.e. the
/// content offset decreases. SwiftUI's `ScrollView` exposes no pan-gesture
/// translation, only content offset (``FeedView``'s
/// `onScrollGeometryChange`), so this rewrite drives the identical show/
/// hide signal off the offset delta directly: a decreasing offset is
/// exactly legacy's `translation.y > 0` case.
public enum FeedScrollDirection: Sendable, Equatable {
	/// Content offset decreasing — legacy's `translation.y > 0` — the
	/// ticker shows.
	case towardStart
	/// Content offset increasing (or unchanged) — legacy's
	/// `translation.y <= 0` — the ticker hides.
	case towardEnd

	/// Pure direction detection from one content-offset change, isolated
	/// from ``FeedView`` so it's unit-testable without a live `ScrollView`
	/// (the tdd skill's boundary: view bodies aren't TDD'd, so any real
	/// logic inside one is extracted). `nil` when `newOffset` is within
	/// `threshold` of `oldOffset` — sub-point jitter (rubber-banding at
	/// the scroll bounds, momentum settling) that isn't a real directional
	/// move; the caller drops these rather than emitting a same-direction
	/// repeat, which is what keeps this signal event-driven (lazy-sections:
	/// "don't drive it from a `.scrollPosition(id:)` binding that writes
	/// state on the main thread continuously while the user scrolls") —
	/// only a genuine change of direction ever reaches a caller.
	public static func from(oldOffset: CGFloat, newOffset: CGFloat, threshold: CGFloat = 0.5) -> FeedScrollDirection? {
		let delta = newOffset - oldOffset
		guard abs(delta) > threshold else { return nil }
		return delta < 0 ? .towardStart : .towardEnd
	}
}
