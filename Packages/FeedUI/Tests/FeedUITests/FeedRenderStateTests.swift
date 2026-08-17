import Testing

@testable import FeedUI

import SecretDJDomain

struct FeedRenderStateTests {
	@Test func `matching hashes need no reload`() {
		let hash = FeedHash(rawValue: "same")

		let state = FeedRenderState(cached: hash, latest: hash)

		#expect(state.needsReload == false)
	}

	@Test func `differing hashes signal a reload is needed`() {
		let state = FeedRenderState(cached: FeedHash(rawValue: "old"), latest: FeedHash(rawValue: "new"))

		#expect(state.needsReload)
	}
}
