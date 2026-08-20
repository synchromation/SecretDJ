import Foundation
import SecretDJDomain
import Testing

@testable import SecretDJAPI

enum JukeboxAPITests {
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

	struct requestsong {
		/// `secretdjv3/SelectSongAPIAccess.swift`'s `selectSong`: `user`,
		/// `venue`, `songid`.
		@Test func `sends user, venue, and songid, and signs the request`() async throws {
			let recorder = RequestRecorder()
			let client = JukeboxAPITests.makeClient(transport: FakeAPITransport(
				outcome: .success(Fixture.data("RequestSong")),
				recorder: recorder,
			))

			_ = try await client.requestSong(
				userId: "00027786_c2eb9af2",
				venueId: "00007022_f86cba2b",
				songId: "140875",
				credential: JukeboxAPITests.credential,
			)

			let request = try #require(recorder.requests.first)
			#expect(request.url?.path == "/requestsong")
			let parameters = try percentEncodedParameters(of: request)
			#expect(parameters["user"] == "00027786_c2eb9af2")
			#expect(parameters["venue"] == "00007022_f86cba2b")
			#expect(parameters["songid"] == "140875")
			#expect(parameters["sig"] != nil)
		}

		/// `RequestSong.json`: `ReturnCode: 0`, a multi-line `Text` toast, no
		/// `Url`.
		@Test func `decodes a zero return code as success, carrying the server's toast copy`() async throws {
			let client = JukeboxAPITests.makeClient(
				transport: FakeAPITransport(outcome: .success(Fixture.data("RequestSong"))),
			)

			let response = try await client.requestSong(
				userId: "u", venueId: "v", songId: "s",
				credential: JukeboxAPITests.credential,
			)

			guard case .success(let message, let url, let richToast) = response.payload else {
				Issue.record("expected .success, got \(response.payload)")
				return
			}
			#expect(message == """
			Thanks, your song has been added to the queue.

			oliverk is DJ
			adam.s is Top Dog of Bench.

			You can pick 18 more songs here today.
			""")
			#expect(url == nil)
			// `RequestSong.json`'s top-level `Vips` array is a different, unread
			// field (`SelectSongAPIAccess.swift`'s `handle(dictionary:)` never
			// reads it) — this fixture carries no real `Response.Data`.
			#expect(richToast == nil)
		}

		/// `requestsong`'s `Response.Data` (S8.6) — see
		/// ``SecretDJDomain/RichToastData``'s own LIVE-CAPTURE doc comment: no
		/// fixture carries this shape, so this JSON is synthesized from
		/// `RichToastView.swift`'s contract.
		@Test func `decodes a Data payload as the success case's rich toast`() async throws {
			let json = Data(
				#"{"Success": true, "Response": {"ReturnCode": 0, "Data": {"Title": "Reward!"}}}"#.utf8,
			)
			let client = JukeboxAPITests.makeClient(transport: FakeAPITransport(outcome: .success(json)))

			let response = try await client.requestSong(
				userId: "u", venueId: "v", songId: "s",
				credential: JukeboxAPITests.credential,
			)

			guard case .success(_, _, let richToast) = response.payload else {
				Issue.record("expected .success, got \(response.payload)")
				return
			}
			#expect(richToast?.title == "Reward!")
		}

		/// No legacy fixture carries `ImageSize` at all (neither `RequestSong.json`
		/// nor `RequestSongFail.json`) — the out-of-credits branch and its
		/// `ImageSize` field are entirely unconfirmed by a real capture.
		/// // LIVE-CAPTURE: a genuine `-8` response's envelope shape (and
		/// whether `ImageSize` is really present) isn't evidenced; this JSON is
		/// constructed from the documented contract (LEGACY.md business rule 5,
		/// `secretdjv3/SelectSongAPIAccess.swift`'s `handle(dictionary:)`).
		struct `Out of credits (business rule 5)` {
			@Test func `a positive ImageSize offers the top-up screen`() async throws {
				let json = Data(#"{"Success": true, "Response": {"ReturnCode": -8, "ImageSize": 640}}"#.utf8)
				let client = JukeboxAPITests.makeClient(transport: FakeAPITransport(outcome: .success(json)))

				let response = try await client.requestSong(
					userId: "u", venueId: "v", songId: "s",
					credential: JukeboxAPITests.credential,
				)

				#expect(response.payload == .outOfCredits(hasProfilePicture: true))
			}

			@Test func `a zero ImageSize offers the pic-for-credits upsell`() async throws {
				let json = Data(#"{"Success": true, "Response": {"ReturnCode": -8, "ImageSize": 0}}"#.utf8)
				let client = JukeboxAPITests.makeClient(transport: FakeAPITransport(outcome: .success(json)))

				let response = try await client.requestSong(
					userId: "u", venueId: "v", songId: "s",
					credential: JukeboxAPITests.credential,
				)

				#expect(response.payload == .outOfCredits(hasProfilePicture: false))
			}

			/// `secretdjv3/SelectSongAPIAccess.swift`'s `handle(dictionary:)`:
			/// `responseDictionary["ImageSize"] as? Int ?? 1` — a missing field
			/// defaults to `1` (assume a picture exists), not `0`. Preserved
			/// exactly (D7) rather than "fixed" to a `0` default.
			@Test func `a missing ImageSize defaults to assuming a profile picture exists`() async throws {
				let json = Data(#"{"Success": true, "Response": {"ReturnCode": -8}}"#.utf8)
				let client = JukeboxAPITests.makeClient(transport: FakeAPITransport(outcome: .success(json)))

				let response = try await client.requestSong(
					userId: "u", venueId: "v", songId: "s",
					credential: JukeboxAPITests.credential,
				)

				#expect(response.payload == .outOfCredits(hasProfilePicture: true))
			}
		}

		@Test func `any other non-zero return code is a failure carrying the server's message`() async throws {
			let json = Data(#"{"Success": true, "Response": {"ReturnCode": -1, "Text": "Song unavailable."}}"#.utf8)
			let client = JukeboxAPITests.makeClient(transport: FakeAPITransport(outcome: .success(json)))

			let response = try await client.requestSong(
				userId: "u", venueId: "v", songId: "s",
				credential: JukeboxAPITests.credential,
			)

			#expect(response.payload == .failure(message: "Song unavailable."))
		}

		/// `RequestSongFail.json` marks the envelope `Success: false` alongside
		/// `ReturnCode: -8` — unlike every sibling ReturnCode-carrying failure
		/// fixture (`PasswordChangeFail.json`, `RedeemVoucherFail.json`,
		/// `TopUpFail.json`), which all mark `Success: true` even for a
		/// non-zero business `ReturnCode` (envelope `Success` gates transport/
		/// auth-level outcome; `ReturnCode` inside `Response` carries the
		/// business outcome). Treated here as a fixture-authoring mistake
		/// rather than a real contract to special-case: `requestsong` gates on
		/// the envelope exactly like every other endpoint in this package, so
		/// this fixture throws instead of surfacing `.outOfCredits`.
		/// // LIVE-CAPTURE: a genuine out-of-credits response would confirm
		/// whether production really sends `Success: false` here.
		@Test func `throws server on the legacy RequestSongFail fixture's Success false envelope`() async {
			let client = JukeboxAPITests.makeClient(
				transport: FakeAPITransport(outcome: .success(Fixture.data("RequestSongFail"))),
			)

			await #expect(throws: APIError.self) {
				_ = try await client.requestSong(
					userId: "u", venueId: "v", songId: "s",
					credential: JukeboxAPITests.credential,
				)
			}
		}
	}

	struct like {
		/// `secretdjv3/LikeAPIAccess.swift`'s `updateLikeStatus`: `user`,
		/// `item`, `type`, optional `venue`.
		@Test func `sends user, item, and type bitmask, and signs the request`() async throws {
			let recorder = RequestRecorder()
			let client = JukeboxAPITests.makeClient(transport: FakeAPITransport(
				outcome: .success(Fixture.data("Like")),
				recorder: recorder,
			))

			_ = try await client.like(
				userId: "00027786_c2eb9af2",
				venueId: "00007022_f86cba2b",
				item: "140875",
				type: .song,
				credential: JukeboxAPITests.credential,
			)

			let request = try #require(recorder.requests.first)
			#expect(request.url?.path == "/like")
			let parameters = try percentEncodedParameters(of: request)
			#expect(parameters["user"] == "00027786_c2eb9af2")
			#expect(parameters["item"] == "140875")
			#expect(parameters["type"] == "2")
			#expect(parameters["venue"] == "00007022_f86cba2b")
			#expect(parameters["sig"] != nil)
		}

		@Test func `omits venue when none is supplied`() async throws {
			let recorder = RequestRecorder()
			let client = JukeboxAPITests.makeClient(transport: FakeAPITransport(
				outcome: .success(Fixture.data("Like")),
				recorder: recorder,
			))

			_ = try await client.like(
				userId: "u", venueId: nil, item: "i", type: .song,
				credential: JukeboxAPITests.credential,
			)

			let request = try #require(recorder.requests.first)
			let parameters = try percentEncodedParameters(of: request)
			#expect(parameters["venue"] == nil)
		}

		/// `Like.json`: `Response.{Text,Url,LikeInfo.LikedByYou}`.
		@Test func `decodes the toast copy and liked state`() async throws {
			let client = JukeboxAPITests.makeClient(
				transport: FakeAPITransport(outcome: .success(Fixture.data("Like"))),
			)

			let response = try await client.like(
				userId: "u", venueId: "v", item: "140875", type: .song,
				credential: JukeboxAPITests.credential,
			)

			#expect(response.payload.message == "You, pholyfe and 3 other people like 'Inbetween Days'.")
			#expect(response.payload.url == "TESTURL")
			#expect(response.payload.isLikedByYou)
		}
	}

	struct unlike {
		/// Same wire shape as `like`, hitting `/unlike` instead
		/// (`secretdjv3/LikeAPIAccess.swift`'s `like ? .like : .unlike` branch).
		@Test func `posts to the unlike endpoint`() async throws {
			let recorder = RequestRecorder()
			let client = JukeboxAPITests.makeClient(transport: FakeAPITransport(
				outcome: .success(Fixture.data("Like")),
				recorder: recorder,
			))

			_ = try await client.unlike(
				userId: "u", venueId: "v", item: "i", type: .song,
				credential: JukeboxAPITests.credential,
			)

			let request = try #require(recorder.requests.first)
			#expect(request.url?.path == "/unlike")
		}
	}

	struct machinecontrol {
		/// `secretdjv3/MachineControlAPIAccess.swift`'s `changeMood`: action
		/// 400, `item` = the control's action item id, `value` = minutes.
		@Test func `change atmosphere sends action 400 with the mood minutes as value`() async throws {
			let recorder = RequestRecorder()
			let client = JukeboxAPITests.makeClient(transport: FakeAPITransport(
				outcome: .success(Fixture.data("ChangeMood")),
				recorder: recorder,
			))

			_ = try await client.machineControl(
				userId: "u", venueId: "v", action: .changeAtmosphere, item: "42", value: 15,
				credential: JukeboxAPITests.credential,
			)

			let request = try #require(recorder.requests.first)
			#expect(request.url?.path == "/machinecontrol")
			let parameters = try percentEncodedParameters(of: request)
			#expect(parameters["action"] == "400")
			#expect(parameters["item"] == "42")
			#expect(parameters["value"] == "15")
			#expect(parameters["sig"] != nil)
		}

		/// `secretdjv3/MachineControlAPIAccess.swift`'s `skipTrack`: action
		/// 401, `item` = the song id, `value` = 0.
		@Test func `skip sends action 401 with the song id and value zero`() async throws {
			let recorder = RequestRecorder()
			let client = JukeboxAPITests.makeClient(transport: FakeAPITransport(
				outcome: .success(Fixture.data("SkipTrack")),
				recorder: recorder,
			))

			_ = try await client.machineControl(
				userId: "u", venueId: "v", action: .skip, item: "140875", value: 0,
				credential: JukeboxAPITests.credential,
			)

			let request = try #require(recorder.requests.first)
			let parameters = try percentEncodedParameters(of: request)
			#expect(parameters["action"] == "401")
			#expect(parameters["item"] == "140875")
			#expect(parameters["value"] == "0")
		}

		/// `secretdjv3/MachineControlAPIAccess.swift`'s `blackListTrack`:
		/// action 402.
		@Test func `blacklist sends action 402`() async throws {
			let recorder = RequestRecorder()
			let client = JukeboxAPITests.makeClient(transport: FakeAPITransport(
				outcome: .success(Fixture.data("Blacklist")),
				recorder: recorder,
			))

			_ = try await client.machineControl(
				userId: "u", venueId: "v", action: .blacklist, item: "140875", value: 0,
				credential: JukeboxAPITests.credential,
			)

			let request = try #require(recorder.requests.first)
			let parameters = try percentEncodedParameters(of: request)
			#expect(parameters["action"] == "402")
		}

		/// `ChangeMood.json`/`SkipTrack.json`/`Blacklist.json` all share the
		/// same `Response.{Text,ReturnCode}` shape.
		@Test func `decodes the server's confirmation text`() async throws {
			let client = JukeboxAPITests.makeClient(
				transport: FakeAPITransport(outcome: .success(Fixture.data("SkipTrack"))),
			)

			let response = try await client.machineControl(
				userId: "u", venueId: "v", action: .skip, item: "s", value: 0,
				credential: JukeboxAPITests.credential,
			)

			#expect(response.payload.returnCode == 0)
			#expect(response.payload.text == "We got your request\n\nThe song will change soon.\n")
		}
	}
}
