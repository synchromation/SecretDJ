import Testing

@testable import SecretDJDomain

struct FeedHashTests {
	@Test func `stores the raw value it was given`() {
		let hash = FeedHash(rawValue: "abc123")

		#expect(hash.rawValue == "abc123")
	}

	@Test func `hashes with the same raw value are equal`() {
		let first = FeedHash(rawValue: "abc123")
		let second = FeedHash(rawValue: "abc123")

		#expect(first == second)
	}

	@Test func `hashes with different raw values are not equal`() {
		let first = FeedHash(rawValue: "abc123")
		let second = FeedHash(rawValue: "xyz789")

		#expect(first != second)
	}

	@Test func `equal hashes collapse into one entry in a set`() {
		let hashes: Set<FeedHash> = [FeedHash(rawValue: "abc123"), FeedHash(rawValue: "abc123")]

		#expect(hashes.count == 1)
	}
}
