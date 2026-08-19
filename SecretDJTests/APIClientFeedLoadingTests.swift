import FeedUI
import Foundation
import SecretDJAPI
import SecretDJDomain
import Synchronization
import Testing

@testable import SecretDJ

/// ``APIClientFeedLoading``'s own contract: forward the page, return the
/// fetched payload, propagate a fetch failure, and request a fresh location
/// ahead of every load (legacy's per-fetch location rule — LEGACY.md "Refresh
/// rules"). The session-aware ``APIClientFeedLoading/sessionFeed(sessionStore:locationService:endpoint:)``
/// factory (personId/credential lookup, token rotation, sign-out race) has
/// its own file — `APIClientFeedLoadingSessionFeedTests`.
enum APIClientFeedLoadingTests {
	struct `Loading a page` {
		@Test func `forwards the requested page to fetch`() async throws {
			let recorder = CallRecorder()
			let loader = APIClientFeedLoading(
				fetch: { page in
					recorder.recordFetch(page: page)
					return APIResponse(payload: makeSectionList(), rotatedToken: nil)
				},
				requestLocation: {},
			)

			_ = try await loader.load(page: 2)

			#expect(recorder.pages == [2])
		}

		@Test func `a nil page means a full reload`() async throws {
			let recorder = CallRecorder()
			let loader = APIClientFeedLoading(
				fetch: { page in
					recorder.recordFetch(page: page)
					return APIResponse(payload: makeSectionList(), rotatedToken: nil)
				},
				requestLocation: {},
			)

			_ = try await loader.load(page: nil)

			#expect(recorder.pages == [nil])
		}

		@Test func `returns the fetched payload`() async throws {
			let sectionList = makeSectionList(hash: "v1")
			let loader = APIClientFeedLoading(
				fetch: { _ in APIResponse(payload: sectionList, rotatedToken: nil) },
				requestLocation: {},
			)

			let result = try await loader.load(page: nil)

			#expect(result == sectionList)
		}

		@Test func `propagates a fetch failure`() async {
			let loader = APIClientFeedLoading(
				fetch: { _ in throw FakeFetchError() },
				requestLocation: {},
			)

			await #expect(throws: FakeFetchError.self) {
				try await loader.load(page: nil)
			}
		}
	}

	struct `Requesting a fresh location` {
		@Test func `requests a location before fetching`() async throws {
			let recorder = CallRecorder()
			let loader = APIClientFeedLoading(
				fetch: { _ in APIResponse(payload: makeSectionList(), rotatedToken: nil) },
				requestLocation: { recorder.recordLocationRequest() },
			)

			_ = try await loader.load(page: nil)

			#expect(recorder.locationRequestCount == 1)
		}

		@Test func `requests a fresh location on every load, not just the first`() async throws {
			let recorder = CallRecorder()
			let loader = APIClientFeedLoading(
				fetch: { _ in APIResponse(payload: makeSectionList(), rotatedToken: nil) },
				requestLocation: { recorder.recordLocationRequest() },
			)

			_ = try await loader.load(page: nil)
			_ = try await loader.load(page: 1)

			#expect(recorder.locationRequestCount == 2)
		}
	}
}

// MARK: - Fixtures

struct FakeFetchError: Error, Equatable {}

/// Records calls made from ``APIClientFeedLoading``'s `Sendable` closures —
/// which may be invoked from a nonisolated context — behind a `Mutex` rather
/// than an actor, so assertions right after `await loader.load(page:)` don't
/// race a fire-and-forget hop.
final nonisolated class CallRecorder: Sendable {
	private let storage = Mutex<(pages: [Int?], locationRequests: Int)>((pages: [], locationRequests: 0))

	func recordFetch(page: Int?) {
		storage.withLock { $0.pages.append(page) }
	}

	func recordLocationRequest() {
		storage.withLock { $0.locationRequests += 1 }
	}

	var pages: [Int?] {
		storage.withLock { $0.pages }
	}

	var locationRequestCount: Int {
		storage.withLock { $0.locationRequests }
	}
}

nonisolated func makeSectionList(hash: String = "v1") -> SectionList {
	SectionList(hash: FeedHash(rawValue: hash), sections: [], actions: [])
}
