import Testing

@testable import FeedUI

struct StringFeedTaggedLinesTests {
	@Test func `splits multi-line text on newlines`() {
		#expect("Bohemian Rhapsody\nQueen".feedTaggedLines == ["Bohemian Rhapsody", "Queen"])
	}

	@Test func `drops the trailing empty lines the server appends as an alignment trick`() {
		#expect("Bohemian Rhapsody\nQueen\n\n\n".feedTaggedLines == ["Bohemian Rhapsody", "Queen"])
	}

	@Test func `a single line with no newline stays one element`() {
		#expect("Bohemian Rhapsody".feedTaggedLines == ["Bohemian Rhapsody"])
	}

	@Test func `an empty string has no lines`() {
		#expect("".feedTaggedLines.isEmpty)
	}

	@Test func `preserves an interior blank line`() {
		#expect("Line one\n\nLine three".feedTaggedLines == ["Line one", "", "Line three"])
	}
}
