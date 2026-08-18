import Foundation
import SecretDJDomain
import Testing

@testable import SecretDJAPI

enum HandOffAPITests {
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

	private static var fixedDate: Date {
		var calendar = Calendar(identifier: .gregorian)
		calendar.timeZone = .gmt
		// The fallback is unreachable for these well-formed components; kept
		// non-optional rather than force-unwrapped (swiftlint's
		// `force_unwrapping`).
		return calendar
			.date(from: DateComponents(year: 2026, month: 3, day: 15, hour: 12)) ?? Date(timeIntervalSince1970: 0)
	}

	private static var fixedCalendar: Calendar {
		var calendar = Calendar(identifier: .gregorian)
		calendar.timeZone = .gmt
		return calendar
	}

	struct watchonyoutube {
		/// `secretdjv3/YouTubeApiAccess.swift`'s `watchOnYouTube`: `user`,
		/// `item` = the signed song id, optional `venue`.
		///
		/// // LIVE-CAPTURE: no legacy fixture exists for `watchonyoutube` at
		/// all; request construction is pinned against
		/// `secretdjv3/YouTubeApiAccess.swift` directly.
		@Test func `sends the signed song id as item, and signs the request`() async throws {
			let recorder = RequestRecorder()
			let json = Data(#"{"Success": true, "Response": {"YouTubeId": "abc123"}}"#.utf8)
			let client = HandOffAPITests.makeClient(transport: FakeAPITransport(
				outcome: .success(json),
				recorder: recorder,
			))

			_ = try await client.watchOnYouTube(
				userId: "00027786_c2eb9af2",
				venueId: "00007022_f86cba2b",
				songId: "140875",
				date: HandOffAPITests.fixedDate,
				calendar: HandOffAPITests.fixedCalendar,
				credential: HandOffAPITests.credential,
			)

			let request = try #require(recorder.requests.first)
			#expect(request.url?.path == "/watchonyoutube")
			let parameters = try percentEncodedParameters(of: request)
			#expect(parameters["user"] == "00027786_c2eb9af2")
			#expect(parameters["venue"] == "00007022_f86cba2b")
			#expect(
				parameters["item"] ==
					SongSignature.signedSongId(
						songId: "140875",
						date: HandOffAPITests.fixedDate,
						calendar: HandOffAPITests.fixedCalendar,
					),
			)
			#expect(parameters["sig"] != nil)
		}

		@Test func `omits venue when none is supplied`() async throws {
			let recorder = RequestRecorder()
			let json = Data(#"{"Success": true, "Response": {"YouTubeId": "abc123"}}"#.utf8)
			let client = HandOffAPITests.makeClient(transport: FakeAPITransport(
				outcome: .success(json),
				recorder: recorder,
			))

			_ = try await client.watchOnYouTube(
				userId: "u", venueId: nil, songId: "s",
				date: HandOffAPITests.fixedDate, calendar: HandOffAPITests.fixedCalendar,
				credential: HandOffAPITests.credential,
			)

			let request = try #require(recorder.requests.first)
			let parameters = try percentEncodedParameters(of: request)
			#expect(parameters["venue"] == nil)
		}

		/// `secretdjv3/YouTubeApiAccess.swift`'s `parseResult`: a present
		/// `YouTubeId` wins outright.
		@Test func `decodes a present YouTubeId as a direct video hand-off`() async throws {
			let json = Data(#"{"Success": true, "Response": {"YouTubeId": "abc123"}}"#.utf8)
			let client = HandOffAPITests.makeClient(transport: FakeAPITransport(outcome: .success(json)))

			let response = try await client.watchOnYouTube(
				userId: "u", venueId: "v", songId: "s",
				date: HandOffAPITests.fixedDate, calendar: HandOffAPITests.fixedCalendar,
				credential: HandOffAPITests.credential,
			)

			#expect(response.payload == .video(youTubeId: "abc123"))
		}

		/// `secretdjv3/YouTubeApiAccess.swift`'s `parseResult`: a missing
		/// `YouTubeId` falls back to `Title + ExtraInfo.Raw.Title + Artist +
		/// ExtraInfo.Raw.Artist`, space-joined, empty extras skipped.
		@Test func `decodes a missing YouTubeId as a title-artist search query`() async throws {
			let json = Data(
				#"""
				{"Success": true, "Response": {
				  "Title": "Inbetween Days", "Artist": "The Cure",
				  "ExtraInfo": {"Raw": {"Title": "12in Mix", "Artist": "feat. Someone"}}
				}}
				"""#.utf8,
			)
			let client = HandOffAPITests.makeClient(transport: FakeAPITransport(outcome: .success(json)))

			let response = try await client.watchOnYouTube(
				userId: "u", venueId: "v", songId: "s",
				date: HandOffAPITests.fixedDate, calendar: HandOffAPITests.fixedCalendar,
				credential: HandOffAPITests.credential,
			)

			#expect(response.payload == .searchQuery("Inbetween Days 12in Mix The Cure feat. Someone"))
		}

		@Test func `decodes a missing YouTubeId with no extra info as a plain title-artist query`() async throws {
			let json = Data(#"{"Success": true, "Response": {"Title": "Inbetween Days", "Artist": "The Cure"}}"#.utf8)
			let client = HandOffAPITests.makeClient(transport: FakeAPITransport(outcome: .success(json)))

			let response = try await client.watchOnYouTube(
				userId: "u", venueId: "v", songId: "s",
				date: HandOffAPITests.fixedDate, calendar: HandOffAPITests.fixedCalendar,
				credential: HandOffAPITests.credential,
			)

			#expect(response.payload == .searchQuery("Inbetween Days The Cure"))
		}
	}

	struct checkin {
		/// `secretdjv3/CheckInAPIAccess.swift`'s `checkIn`: `user`, `venue`,
		/// `scope`. Business rule 12 (LEGACY.md): "Check-ins always sent with
		/// `scope=everyone`" — the default.
		@Test func `defaults to scope everyone, per business rule 12`() async throws {
			let recorder = RequestRecorder()
			let client = HandOffAPITests.makeClient(transport: FakeAPITransport(
				outcome: .success(Fixture.data("CheckIn")),
				recorder: recorder,
			))

			_ = try await client.checkIn(
				userId: "00027786_c2eb9af2",
				venueId: "00007022_f86cba2b",
				credential: HandOffAPITests.credential,
			)

			let request = try #require(recorder.requests.first)
			#expect(request.url?.path == "/checkin")
			let parameters = try percentEncodedParameters(of: request)
			#expect(parameters["user"] == "00027786_c2eb9af2")
			#expect(parameters["venue"] == "00007022_f86cba2b")
			#expect(parameters["scope"] == "1")
			#expect(parameters["sig"] != nil)
		}

		@Test func `an explicit scope overrides the default`() async throws {
			let recorder = RequestRecorder()
			let client = HandOffAPITests.makeClient(transport: FakeAPITransport(
				outcome: .success(Fixture.data("CheckIn")),
				recorder: recorder,
			))

			_ = try await client.checkIn(
				userId: "u", venueId: "v", scope: .incognito,
				credential: HandOffAPITests.credential,
			)

			let request = try #require(recorder.requests.first)
			let parameters = try percentEncodedParameters(of: request)
			#expect(parameters["scope"] == "2")
		}

		/// `CheckIn.json`: `Sections[0].Custom.Response.{Text,ReturnCode,Url}`
		/// — nested under the section's `Custom`, not a top-level `Response`
		/// (LEGACY.md's catalog: "`Sections[0].Custom.Response.{Text,Url,Data}`").
		@Test func `decodes the toast copy from the first section's Custom Response`() async throws {
			let client = HandOffAPITests.makeClient(
				transport: FakeAPITransport(outcome: .success(Fixture.data("CheckIn"))),
			)

			let response = try await client.checkIn(
				userId: "u", venueId: "v",
				credential: HandOffAPITests.credential,
			)

			#expect(response.payload.text == "Welcome, this is your first visit here.")
			#expect(response.payload.url == "TESTURL")
			#expect(response.payload.returnCode == 2)
		}
	}
}
