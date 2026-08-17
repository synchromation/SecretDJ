import SwiftUI

// Implicitly Sendable value types: internal types whose stored properties
// are all Sendable conform by construction, so no explicit conformance is
// declared (the formatter strips it as redundant). Every random or
// formatted thing a cell shows (titles, subtitles, colors, symbols) is
// computed ONCE when the section is built, never inside a view body. Bodies
// stay pure and cheap, and because cells receive only immutable values,
// nothing in the scrolling content observes anything — scrolling triggers
// zero invalidation.

/// The layout a backend-driven feed section renders as.
enum SectionKind {
	case list
	case carousel
	case grid

	/// Names the concrete lazy container behind each kind. Demo
	/// instrumentation for ``SectionHeader``'s badge, not real product
	/// copy — hidden from VoiceOver for the same reason.
	var badgeLabel: String {
		switch self {
		case .list: "LazyVStack"
		case .carousel: "LazyHStack"
		case .grid: "LazyVGrid"
		}
	}

	/// Maps a backend section-kind string to its typed case. Unknown kinds
	/// return `nil` so the caller can drop those sections instead of
	/// crashing or guessing a fallback layout.
	init?(serverKind: String) {
		switch serverKind {
		case "list": self = .list
		case "carousel": self = .carousel
		case "grid": self = .grid
		default: return nil
		}
	}
}
