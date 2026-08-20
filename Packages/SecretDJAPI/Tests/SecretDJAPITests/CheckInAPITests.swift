import Foundation
import SecretDJDomain
import Testing

@testable import SecretDJAPI

enum CheckInAPITests {
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

	struct checkin {
		/// `secretdjv3/CheckInAPIAccess.swift`'s `checkIn`: `user`, `venue`,
		/// `scope`. Business rule 12 (LEGACY.md): "Check-ins always sent with
		/// `scope=everyone`" — the default.
		@Test func `defaults to scope everyone, per business rule 12`() async throws {
			let recorder = RequestRecorder()
			let client = CheckInAPITests.makeClient(transport: FakeAPITransport(
				outcome: .success(Fixture.data("CheckIn")),
				recorder: recorder,
			))

			_ = try await client.checkIn(
				userId: "00027786_c2eb9af2",
				venueId: "00007022_f86cba2b",
				credential: CheckInAPITests.credential,
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
			let client = CheckInAPITests.makeClient(transport: FakeAPITransport(
				outcome: .success(Fixture.data("CheckIn")),
				recorder: recorder,
			))

			_ = try await client.checkIn(
				userId: "u", venueId: "v", scope: .incognito,
				credential: CheckInAPITests.credential,
			)

			let request = try #require(recorder.requests.first)
			let parameters = try percentEncodedParameters(of: request)
			#expect(parameters["scope"] == "2")
		}

		/// `CheckIn.json`: `Sections[0].Custom.Response.{Text,ReturnCode,Url}`
		/// — nested under the section's `Custom`, not a top-level `Response`
		/// (LEGACY.md's catalog: "`Sections[0].Custom.Response.{Text,Url,Data}`").
		@Test func `decodes the toast copy from the first section's Custom Response`() async throws {
			let client = CheckInAPITests.makeClient(
				transport: FakeAPITransport(outcome: .success(Fixture.data("CheckIn"))),
			)

			let response = try await client.checkIn(
				userId: "u", venueId: "v",
				credential: CheckInAPITests.credential,
			)

			#expect(response.payload.text == "Welcome, this is your first visit here.")
			#expect(response.payload.url == "TESTURL")
			#expect(response.payload.returnCode == 2)
			// `CheckIn.json` carries no `Data` field — see
			// ``SecretDJDomain/RichToastData``'s own LIVE-CAPTURE doc comment.
			#expect(response.payload.data == nil)
		}

		/// `checkin`'s `Response.Data` (S8.6) — see
		/// ``SecretDJDomain/RichToastData``'s own LIVE-CAPTURE doc comment: no
		/// fixture carries this shape, so this JSON is synthesized from
		/// `RichToastView.swift`'s contract.
		@Test func `decodes a Data payload as a rich toast`() async throws {
			let json = Data(
				"""
				{"Sections": [{"Custom": {"Response": {
				  "ReturnCode": 0, "Text": "Welcome!", "Data": {"Title": "Reward!"}
				}}}], "Success": true}
				""".utf8,
			)
			let client = CheckInAPITests.makeClient(transport: FakeAPITransport(outcome: .success(json)))

			let response = try await client.checkIn(
				userId: "u", venueId: "v",
				credential: CheckInAPITests.credential,
			)

			#expect(response.payload.data?.title == "Reward!")
		}
	}
}
