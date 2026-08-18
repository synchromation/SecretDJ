import Foundation
import SecretDJDomain
import Testing

@testable import SecretDJAPI

enum MusicSelectionAPITests {
	private static func makeClient(transport: some APITransport) -> APIClient {
		APIClient(
			configuration: APIClientConfiguration(
				environment: .production,
				deviceIdentifier: "idfv",
				screenWidth: 390,
				clientVersion: "5.1.4",
				isKiosk: false,
			),
			implicitParameters: FakeImplicitParameterProvider(),
			transport: transport,
		)
	}

	private static let credential = APICredential(
		token: "kPV0J8Q+DVABopusWMnQkc6kldY=",
		passwordHash: "889101801761492e1a2140d491c4235a1798e284",
	)

	struct musicselection {
		/// `secretdjv3/MusicAPIAccess.swift`'s `musicSelection` (via
		/// `updateMusic`): `user`, `venue`, `offset`, `numentries`, `item`,
		/// `type`, optional `hash`.
		@Test func `sends every paging parameter and signs the request`() async throws {
			let recorder = RequestRecorder()
			let client = MusicSelectionAPITests.makeClient(transport: FakeAPITransport(
				outcome: .success(Fixture.data("MusicSelection")),
				recorder: recorder,
			))

			_ = try await client.musicSelection(
				userId: "00027786_c2eb9af2",
				venueId: "00007022_f86cba2b",
				offset: 50,
				batchSize: 50,
				item: 12,
				type: 2,
				hash: nil,
				credential: MusicSelectionAPITests.credential,
			)

			let request = try #require(recorder.requests.first)
			#expect(request.url?.path == "/musicselection")
			let parameters = try percentEncodedParameters(of: request)
			#expect(parameters["user"] == "00027786_c2eb9af2")
			#expect(parameters["venue"] == "00007022_f86cba2b")
			#expect(parameters["offset"] == "50")
			#expect(parameters["numentries"] == "50")
			#expect(parameters["item"] == "12")
			#expect(parameters["type"] == "2")
			#expect(parameters["hash"] == nil)
			#expect(parameters["sig"] != nil)
		}

		@Test func `sends hash when supplied, for pagination`() async throws {
			let recorder = RequestRecorder()
			let client = MusicSelectionAPITests.makeClient(transport: FakeAPITransport(
				outcome: .success(Fixture.data("MusicSelection")),
				recorder: recorder,
			))

			_ = try await client.musicSelection(
				userId: "u", venueId: "v", offset: 0, batchSize: 50, item: 0, type: 0,
				hash: FeedHash(rawValue: "adjfa92"),
				credential: MusicSelectionAPITests.credential,
			)

			let request = try #require(recorder.requests.first)
			let parameters = try percentEncodedParameters(of: request)
			#expect(parameters["hash"] == "adjfa92")
		}

		/// `MusicSelection.json`, pinned in full by
		/// `SectionListDecoderFixtureTests`: the section's own `Custom.Hash`
		/// ("adjfa92") is what S1.3e's pagination reads back as `hash` on
		/// the next call — already present on
		/// ``SecretDJDomain/Section/hash``, so no bespoke wrapper type is
		/// needed here.
		@Test func `decodes the response as a SectionList whose section carries the pagination hash`() async throws {
			let client = MusicSelectionAPITests.makeClient(
				transport: FakeAPITransport(outcome: .success(Fixture.data("MusicSelection"))),
			)

			let response = try await client.musicSelection(
				userId: "u", venueId: "v", offset: 0, batchSize: 50, item: 0, type: 0, hash: nil,
				credential: MusicSelectionAPITests.credential,
			)

			#expect(response.payload.sections.first?.hash == FeedHash(rawValue: "adjfa92"))
		}
	}

	struct musicdigest {
		/// Same shape as `musicselection`, hitting `musicdigest`
		/// (`secretdjv3/MusicAPIAccess.swift`'s `musicDigest`).
		@Test func `sends every paging parameter to the musicdigest endpoint`() async throws {
			let recorder = RequestRecorder()
			let json = Data(#"{"Success": true, "Sections": []}"#.utf8)
			let client = MusicSelectionAPITests.makeClient(transport: FakeAPITransport(
				outcome: .success(json),
				recorder: recorder,
			))

			_ = try await client.musicDigest(
				userId: "u", venueId: "v", offset: 0, batchSize: 50, item: 0, type: 0, hash: nil,
				credential: MusicSelectionAPITests.credential,
			)

			let request = try #require(recorder.requests.first)
			#expect(request.url?.path == "/musicdigest")
		}

		/// `Live/MusicDigest.json` — a production `musicdigest` capture
		/// (S1's R2 live-capture pass): three sections ("The Lamb", "Our
		/// Jukeboxes", "More Music For You"). No legacy fixture existed for
		/// `musicdigest` specifically. Unlike `APIClient+MusicSelection.swift`'s
		/// doc comment claims ("none of these responses carry a top-level
		/// `Hash`"), this live response *does* carry one (`"eed5efae"`,
		/// matching its first section's own `Custom.Hash`) — harmless since
		/// `SectionList.hash` already decodes it, and callers page off each
		/// section's own hash regardless, but worth a genuine wire-contract
		/// note rather than silently contradicting that comment.
		@Test func `decodes the response as a SectionList`() async throws {
			let client = MusicSelectionAPITests.makeClient(
				transport: FakeAPITransport(outcome: .success(Fixture.liveData("MusicDigest"))),
			)

			let response = try await client.musicDigest(
				userId: "u", venueId: "v", offset: 0, batchSize: 50, item: 0, type: 0, hash: nil,
				credential: MusicSelectionAPITests.credential,
			)

			#expect(response.payload.sections.count == 3)
			#expect(response.payload.sections.map(\.title) == ["The Lamb", "Our Jukeboxes", "More Music For You"])
			#expect(response.payload.hash == FeedHash(rawValue: "eed5efae"))
		}
	}

	struct styleinfo {
		/// `secretdjv3/MachineControlAPIAccess.swift`'s `styleInformation`:
		/// `user`, `venue`, `offset`, `numentries`, `item`, optional `hash`
		/// — no `type` parameter, unlike `musicselection`/`musicdigest`.
		@Test func `sends every paging parameter and signs the request`() async throws {
			let recorder = RequestRecorder()
			let client = MusicSelectionAPITests.makeClient(transport: FakeAPITransport(
				outcome: .success(Fixture.data("StyleInfo")),
				recorder: recorder,
			))

			_ = try await client.styleInfo(
				userId: "00027786_c2eb9af2",
				venueId: "00007022_f86cba2b",
				offset: 0,
				batchSize: 50,
				item: 0,
				hash: nil,
				credential: MusicSelectionAPITests.credential,
			)

			let request = try #require(recorder.requests.first)
			#expect(request.url?.path == "/styleinfo")
			let parameters = try percentEncodedParameters(of: request)
			#expect(parameters["user"] == "00027786_c2eb9af2")
			#expect(parameters["venue"] == "00007022_f86cba2b")
			#expect(parameters["offset"] == "0")
			#expect(parameters["numentries"] == "50")
			#expect(parameters["item"] == "0")
			#expect(parameters["type"] == nil)
			#expect(parameters["sig"] != nil)
		}

		@Test func `sends hash when supplied, for pagination`() async throws {
			let recorder = RequestRecorder()
			let client = MusicSelectionAPITests.makeClient(transport: FakeAPITransport(
				outcome: .success(Fixture.data("StyleInfo")),
				recorder: recorder,
			))

			_ = try await client.styleInfo(
				userId: "u", venueId: "v", offset: 0, batchSize: 50, item: 0,
				hash: FeedHash(rawValue: "2a31478b"),
				credential: MusicSelectionAPITests.credential,
			)

			let request = try #require(recorder.requests.first)
			let parameters = try percentEncodedParameters(of: request)
			#expect(parameters["hash"] == "2a31478b")
		}

		/// `StyleInfo.json`, pinned in full by
		/// `SectionListDecoderFixtureTests`
		/// (`secret-dj-ios-old/SecretDJTests/MachineControlAPIAccessTests.swift`'s
		/// `testCanParseStyleInfo`: hash `2a31478b`).
		@Test func `decodes the response as a SectionList whose song section carries the pagination hash`(
		) async throws {
			let client = MusicSelectionAPITests.makeClient(
				transport: FakeAPITransport(outcome: .success(Fixture.data("StyleInfo"))),
			)

			let response = try await client.styleInfo(
				userId: "u", venueId: "v", offset: 0, batchSize: 50, item: 0, hash: nil,
				credential: MusicSelectionAPITests.credential,
			)

			let songSection = try #require(response.payload.sections.dropFirst().first)
			#expect(songSection.hash == FeedHash(rawValue: "2a31478b"))
		}
	}
}
