import Foundation
import SecretDJDomain
import Testing

@testable import SecretDJAPI

enum FeedAPITests {
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

	struct placesnearby {
		/// `secretdjv3/FeedAPIAccess.swift`'s `placesNearby`: `user` only.
		@Test func `sends the user id and signs the request`() async throws {
			let recorder = RequestRecorder()
			let client = FeedAPITests.makeClient(transport: FakeAPITransport(
				outcome: .success(Fixture.data("PlacesNearby")),
				recorder: recorder,
			))

			_ = try await client.placesNearby(userId: "00027786_c2eb9af2", credential: FeedAPITests.credential)

			let request = try #require(recorder.requests.first)
			#expect(request.url?.path == "/placesnearby")
			let parameters = try percentEncodedParameters(of: request)
			#expect(parameters["user"] == "00027786_c2eb9af2")
			// `placesnearby` is absent from the sig-exclusion list
			// (`secretdjv3/NetworkAccess.swift:209`), so it always signs.
			#expect(parameters["sig"] != nil)
		}

		/// `PlacesNearby.json` — the legacy `placesnearby` fixture,
		/// pinned in full by `SectionListDecoderFixtureTests`; this only
		/// confirms the envelope threads through to a `SectionList`.
		@Test func `decodes the response as a SectionList`() async throws {
			let client = FeedAPITests.makeClient(
				transport: FakeAPITransport(outcome: .success(Fixture.data("PlacesNearby"))),
			)

			let response = try await client.placesNearby(userId: "u", credential: FeedAPITests.credential)

			#expect(response.payload.sections.count == 4)
		}
	}

	struct venue {
		/// `secretdjv3/FeedAPIAccess.swift`'s `venue`: `user` + `venue`,
		/// hitting `venuedetails`.
		@Test func `sends the user and venue ids and signs the request`() async throws {
			let recorder = RequestRecorder()
			let client = FeedAPITests.makeClient(transport: FakeAPITransport(
				outcome: .success(Fixture.data("VenueFeed")),
				recorder: recorder,
			))

			_ = try await client.venue(
				userId: "00027786_c2eb9af2",
				venueId: "00007022_f86cba2b",
				credential: FeedAPITests.credential,
			)

			let request = try #require(recorder.requests.first)
			#expect(request.url?.path == "/venuedetails")
			let parameters = try percentEncodedParameters(of: request)
			#expect(parameters["user"] == "00027786_c2eb9af2")
			#expect(parameters["venue"] == "00007022_f86cba2b")
			#expect(parameters["sig"] != nil)
		}

		@Test func `decodes the response as a SectionList`() async throws {
			let client = FeedAPITests.makeClient(
				transport: FakeAPITransport(outcome: .success(Fixture.data("VenueFeed"))),
			)

			let response = try await client.venue(userId: "u", venueId: "v", credential: FeedAPITests.credential)

			#expect(response.payload.sections.count == 4)
		}
	}

	struct activity {
		/// `secretdjv3/FeedAPIAccess.swift`'s `activity`: `user` only,
		/// hitting `eventhistory`.
		@Test func `sends the user id and signs the request`() async throws {
			let recorder = RequestRecorder()
			let client = FeedAPITests.makeClient(transport: FakeAPITransport(
				outcome: .success(Fixture.data("EventHistory")),
				recorder: recorder,
			))

			_ = try await client.activity(userId: "00027786_c2eb9af2", credential: FeedAPITests.credential)

			let request = try #require(recorder.requests.first)
			#expect(request.url?.path == "/eventhistory")
			let parameters = try percentEncodedParameters(of: request)
			#expect(parameters["user"] == "00027786_c2eb9af2")
			#expect(parameters["sig"] != nil)
		}

		@Test func `decodes the response as a SectionList`() async throws {
			let client = FeedAPITests.makeClient(
				transport: FakeAPITransport(outcome: .success(Fixture.data("EventHistory"))),
			)

			let response = try await client.activity(userId: "u", credential: FeedAPITests.credential)

			#expect(response.payload.sections.first?.items.count == 50)
		}
	}

	struct profile {
		/// `secretdjv3/FeedAPIAccess.swift`'s `profile`: `user` + `person`,
		/// hitting `persondetails`.
		@Test func `sends the user and profile person ids and signs the request`() async throws {
			let recorder = RequestRecorder()
			let client = FeedAPITests.makeClient(transport: FakeAPITransport(
				outcome: .success(Fixture.data("PersonDetails")),
				recorder: recorder,
			))

			_ = try await client.profile(
				userId: "00027786_c2eb9af2",
				profileUserId: "00027786_c2eb9af2",
				credential: FeedAPITests.credential,
			)

			let request = try #require(recorder.requests.first)
			#expect(request.url?.path == "/persondetails")
			let parameters = try percentEncodedParameters(of: request)
			#expect(parameters["user"] == "00027786_c2eb9af2")
			#expect(parameters["person"] == "00027786_c2eb9af2")
			#expect(parameters["sig"] != nil)
		}

		@Test func `decodes the response as a SectionList`() async throws {
			let client = FeedAPITests.makeClient(
				transport: FakeAPITransport(outcome: .success(Fixture.data("PersonDetails"))),
			)

			let response = try await client.profile(
				userId: "u",
				profileUserId: "p",
				credential: FeedAPITests.credential,
			)

			#expect(response.payload.sections.count == 3)
		}
	}

	struct nowplaying {
		/// `secretdjv3/FeedAPIAccess.swift`'s `nowPlaying`: `user` +
		/// `venue`, hitting `playhistory`.
		@Test func `sends the user and venue ids and signs the request`() async throws {
			let recorder = RequestRecorder()
			let json = Data(#"{"Success": true, "Sections": []}"#.utf8)
			let client = FeedAPITests.makeClient(transport: FakeAPITransport(
				outcome: .success(json),
				recorder: recorder,
			))

			_ = try await client.nowPlaying(
				userId: "00027786_c2eb9af2",
				venueId: "00007022_f86cba2b",
				credential: FeedAPITests.credential,
			)

			let request = try #require(recorder.requests.first)
			#expect(request.url?.path == "/playhistory")
			let parameters = try percentEncodedParameters(of: request)
			#expect(parameters["user"] == "00027786_c2eb9af2")
			#expect(parameters["venue"] == "00007022_f86cba2b")
			#expect(parameters["sig"] != nil)
		}

		/// // LIVE-CAPTURE: no legacy fixture exists for `playhistory`
		/// (the legacy test resources have no now-playing capture); this
		/// only proves the envelope threads through to a `SectionList`.
		@Test func `decodes the response as a SectionList`() async throws {
			let json = Data(#"{"Success": true, "Sections": [], "Hash": "np-hash"}"#.utf8)
			let client = FeedAPITests.makeClient(transport: FakeAPITransport(outcome: .success(json)))

			let response = try await client.nowPlaying(userId: "u", venueId: "v", credential: FeedAPITests.credential)

			#expect(response.payload.hash == FeedHash(rawValue: "np-hash"))
		}
	}

	struct extracontent {
		/// `secretdjv3/FeedAPIAccess.swift`'s `extraContent`: `user` +
		/// `screenid`, `venue` only when supplied.
		@Test func `sends screenid and omits venue when none is supplied`() async throws {
			let recorder = RequestRecorder()
			let json = Data(#"{"Success": true, "Sections": []}"#.utf8)
			let client = FeedAPITests.makeClient(transport: FakeAPITransport(
				outcome: .success(json),
				recorder: recorder,
			))

			_ = try await client.extraContent(
				userId: "u",
				venueId: nil,
				screen: .placesNearby,
				credential: FeedAPITests.credential,
			)

			let request = try #require(recorder.requests.first)
			#expect(request.url?.path == "/extracontent")
			let parameters = try percentEncodedParameters(of: request)
			#expect(parameters["screenid"] == "1")
			#expect(parameters["venue"] == nil)
			#expect(parameters["sig"] != nil)
		}

		@Test func `sends venue when supplied, with the venueDetails screen id`() async throws {
			let recorder = RequestRecorder()
			let json = Data(#"{"Success": true, "Sections": []}"#.utf8)
			let client = FeedAPITests.makeClient(transport: FakeAPITransport(
				outcome: .success(json),
				recorder: recorder,
			))

			_ = try await client.extraContent(
				userId: "u",
				venueId: "v",
				screen: .venueDetails,
				credential: FeedAPITests.credential,
			)

			let request = try #require(recorder.requests.first)
			let parameters = try percentEncodedParameters(of: request)
			#expect(parameters["screenid"] == "2")
			#expect(parameters["venue"] == "v")
		}

		/// // LIVE-CAPTURE: no legacy fixture exists for `extracontent`.
		@Test func `decodes the response as a SectionList`() async throws {
			let json = Data(#"{"Success": true, "Sections": []}"#.utf8)
			let client = FeedAPITests.makeClient(transport: FakeAPITransport(outcome: .success(json)))

			let response = try await client.extraContent(
				userId: "u",
				venueId: nil,
				screen: .placesNearby,
				credential: FeedAPITests.credential,
			)

			#expect(response.payload.sections.isEmpty)
		}
	}

	struct promote {
		/// `secretdjv3/FeedAPIAccess.swift`'s `promotionEngaged`: `user` +
		/// `venue` + `id`.
		@Test func `sends the user id, venue id, and promotion id, and signs the request`() async throws {
			let recorder = RequestRecorder()
			let json = Data(#"{"Success": true}"#.utf8)
			let client = FeedAPITests.makeClient(transport: FakeAPITransport(
				outcome: .success(json),
				recorder: recorder,
			))

			_ = try await client.promotionEngaged(
				userId: "00027786_c2eb9af2",
				venueId: "00007022_f86cba2b",
				promotionId: 1000,
				credential: FeedAPITests.credential,
			)

			let request = try #require(recorder.requests.first)
			#expect(request.url?.path == "/promote")
			let parameters = try percentEncodedParameters(of: request)
			#expect(parameters["user"] == "00027786_c2eb9af2")
			#expect(parameters["venue"] == "00007022_f86cba2b")
			#expect(parameters["id"] == "1000")
			#expect(parameters["sig"] != nil)
		}

		/// `secretdjv3/FeedAPIAccess.swift`'s `promotionEngaged` doesn't
		/// read its response at all ("don't care what the result was");
		/// this only proves a bare successful envelope doesn't throw.
		@Test func `decodes successfully regardless of body`() async throws {
			let json = Data(#"{"Success": true}"#.utf8)
			let client = FeedAPITests.makeClient(transport: FakeAPITransport(outcome: .success(json)))

			_ = try await client.promotionEngaged(
				userId: "u",
				venueId: "v",
				promotionId: 1,
				credential: FeedAPITests.credential,
			)
		}
	}
}
