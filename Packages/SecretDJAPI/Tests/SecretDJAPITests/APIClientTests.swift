import Foundation
import Testing

@testable import SecretDJAPI

enum APIClientTests {
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

	struct `A successful call` {
		/// Shape matches `secret-dj-ios-old/SecretDJTests/ChangeMood.json`.
		@Test func `decodes the payload and surfaces the rotated token`() async throws {
			let json = Data(
				"""
				{
				  "Response": {"Text": "We got your request", "ReturnCode": 0},
				  "Success": true,
				  "Token": "EYJZ0cLNUpg5HIBvj1qWQ6uhxfQ="
				}
				""".utf8,
			)
			let client = APIClientTests.makeClient(transport: FakeAPITransport(outcome: .success(json)))

			let response = try await client.execute(
				endpoint: "machinecontrol",
				parameters: [:],
				signed: false,
				credential: nil,
				decodingPayloadAs: APIActionPayload.self,
			)

			#expect(response.payload.response.text == "We got your request")
			#expect(response.rotatedToken == "EYJZ0cLNUpg5HIBvj1qWQ6uhxfQ=")
		}

		@Test func `a missing Token decodes to a nil rotatedToken`() async throws {
			let json = Data(#"{"Success": true, "Response": {"Text": "hi", "ReturnCode": 0}}"#.utf8)
			let client = APIClientTests.makeClient(transport: FakeAPITransport(outcome: .success(json)))

			let response = try await client.execute(
				endpoint: "machinecontrol",
				parameters: [:],
				signed: false,
				credential: nil,
				decodingPayloadAs: APIActionPayload.self,
			)

			#expect(response.rotatedToken == nil)
		}
	}

	struct `A failed envelope` {
		/// Modeled on `secret-dj-ios-old/SecretDJTests/PasswordChangeFail.json`.
		@Test func `throws server with the envelope's message before decoding the payload`() async {
			let json = Data(#"{"Success": false, "Message": "Wrong password."}"#.utf8)
			let client = APIClientTests.makeClient(transport: FakeAPITransport(outcome: .success(json)))

			await #expect(throws: APIError.self) {
				_ = try await client.execute(
					endpoint: "signin",
					parameters: [:],
					signed: false,
					credential: nil,
					decodingPayloadAs: APIActionPayload.self,
				)
			}
		}

		@Test func `the thrown error carries the server's message`() async throws {
			let json = Data(#"{"Success": false, "Message": "Wrong password."}"#.utf8)
			let client = APIClientTests.makeClient(transport: FakeAPITransport(outcome: .success(json)))

			do {
				_ = try await client.execute(
					endpoint: "signin",
					parameters: [:],
					signed: false,
					credential: nil,
					decodingPayloadAs: APIActionPayload.self,
				)
				Issue.record("expected execute to throw")
			} catch APIError.server(let message) {
				#expect(message == "Wrong password.")
			} catch {
				Issue.record("expected .server, got \(error)")
			}
		}
	}

	struct `Transport failure` {
		@Test func `wraps a transport error as APIError transport`() async throws {
			let underlying = StubTransportError(message: "offline")
			let client = APIClientTests.makeClient(transport: FakeAPITransport(outcome: .failure(underlying)))

			do {
				_ = try await client.execute(
					endpoint: "placesnearby",
					parameters: [:],
					signed: false,
					credential: nil,
					decodingPayloadAs: EmptyAPIPayload.self,
				)
				Issue.record("expected execute to throw")
			} catch APIError.transport(let error) {
				#expect(error as? StubTransportError == underlying)
			} catch {
				Issue.record("expected .transport, got \(error)")
			}
		}
	}

	struct `Malformed responses` {
		@Test func `wraps unparseable JSON as APIError decoding`() async throws {
			let notJSON = Data("not json".utf8)
			let client = APIClientTests.makeClient(transport: FakeAPITransport(outcome: .success(notJSON)))

			await #expect(throws: APIError.self) {
				_ = try await client.execute(
					endpoint: "placesnearby",
					parameters: [:],
					signed: false,
					credential: nil,
					decodingPayloadAs: EmptyAPIPayload.self,
				)
			}
		}

		@Test func `a payload missing its expected shape throws decoding, not a crash`() async throws {
			let json = Data(#"{"Success": true, "Token": "x"}"#.utf8)
			let client = APIClientTests.makeClient(transport: FakeAPITransport(outcome: .success(json)))

			do {
				_ = try await client.execute(
					endpoint: "machinecontrol",
					parameters: [:],
					signed: false,
					credential: nil,
					decodingPayloadAs: APIActionPayload.self,
				)
				Issue.record("expected execute to throw")
			} catch APIError.decoding(let error) {
				#expect(error is DecodingError)
			} catch {
				Issue.record("expected .decoding, got \(error)")
			}
		}
	}

	struct `Signing propagation` {
		@Test func `propagates missingCredential from the request builder`() async {
			let client = APIClientTests.makeClient(transport: FakeAPITransport(outcome: .success(Data())))

			await #expect(throws: APIError.self) {
				_ = try await client.execute(
					endpoint: "userdetails",
					parameters: [:],
					signed: true,
					credential: nil,
					decodingPayloadAs: EmptyAPIPayload.self,
				)
			}
		}
	}
}
