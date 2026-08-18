import Foundation
import SecretDJDomain
import Testing

@testable import SecretDJAPI

enum CreditsAPITests {
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

	struct topupdetails {
		/// `secretdjv3/TopUpAPIAccess.swift`'s `topUpOptions`: `user`,
		/// `context`, `vendor`, optional `venue`.
		@Test func `sends context and vendor, and signs the request`() async throws {
			let recorder = RequestRecorder()
			let client = CreditsAPITests.makeClient(transport: FakeAPITransport(
				outcome: .success(Fixture.data("TopUpDetails")),
				recorder: recorder,
			))

			_ = try await client.topUpDetails(
				userId: "00027786_c2eb9af2",
				venueId: "00007022_f86cba2b",
				context: .noCredits,
				vendor: .appleAppStore,
				credential: CreditsAPITests.credential,
			)

			let request = try #require(recorder.requests.first)
			#expect(request.url?.path == "/topupdetails")
			let parameters = try percentEncodedParameters(of: request)
			#expect(parameters["user"] == "00027786_c2eb9af2")
			#expect(parameters["venue"] == "00007022_f86cba2b")
			#expect(parameters["context"] == "1")
			#expect(parameters["vendor"] == "2")
			#expect(parameters["sig"] != nil)
		}

		@Test func `omits venue when none is supplied`() async throws {
			let recorder = RequestRecorder()
			let client = CreditsAPITests.makeClient(transport: FakeAPITransport(
				outcome: .success(Fixture.data("TopUpDetails")),
				recorder: recorder,
			))

			_ = try await client.topUpDetails(
				userId: "u", venueId: nil, context: .insertCoin, vendor: .appleAppStore,
				credential: CreditsAPITests.credential,
			)

			let request = try #require(recorder.requests.first)
			let parameters = try percentEncodedParameters(of: request)
			#expect(parameters["venue"] == nil)
			#expect(parameters["context"] == "0")
		}

		/// `TopUpDetails.json`: one section of four `topUp` template (700)
		/// items, already decodable per S1.1's ``SecretDJDomain/TopUp``.
		@Test func `decodes the section's TopUp items`() async throws {
			let client = CreditsAPITests.makeClient(
				transport: FakeAPITransport(outcome: .success(Fixture.data("TopUpDetails"))),
			)

			let response = try await client.topUpDetails(
				userId: "u", venueId: "v", context: .noCredits, vendor: .appleAppStore,
				credential: CreditsAPITests.credential,
			)

			let section = try #require(response.payload.sections.first)
			#expect(section.items.count == 4)
			guard case .topUp(let firstTopUp) = section.items.first else {
				Issue.record("expected a .topUp item, got \(String(describing: section.items.first))")
				return
			}
			#expect(firstTopUp.sku == "pp01cred01")
			#expect(firstTopUp.numCredits == 1)
			#expect(firstTopUp.displayPrice == "50p")
		}
	}

	struct topupnotify {
		/// `secretdjv3/TopUpAPIAccess.swift`'s `verifyTransaction`: POSTs
		/// `user`, `vendor`, `action`, `uid`, `info` (base64 receipt) as
		/// multipart, always signed.
		@Test func `POSTs a signed multipart body with the purchase confirmation fields`() async throws {
			let recorder = RequestRecorder()
			let client = CreditsAPITests.makeClient(transport: FakeAPITransport(
				outcome: .success(Fixture.data("TopUpSuccess")),
				recorder: recorder,
			))

			_ = try await client.topUpNotify(
				userId: "00027786_c2eb9af2",
				vendor: .appleAppStore,
				action: .paymentReceived,
				transactionId: "txn-123",
				receiptBase64: "ZmFrZS1yZWNlaXB0",
				credential: CreditsAPITests.credential,
			)

			let request = try #require(recorder.requests.first)
			#expect(request.httpMethod == "POST")
			#expect(request.url?.path == "/topupnotify")
			let contentType = try #require(request.value(forHTTPHeaderField: "Content-Type"))
			#expect(contentType.hasPrefix("multipart/form-data; boundary="))

			let text = try bodyText(of: request)
			#expect(text.contains("name=\"user\""))
			#expect(text.contains("00027786_c2eb9af2"))
			#expect(text.contains("name=\"vendor\""))
			#expect(text.contains("name=\"action\""))
			#expect(text.contains("name=\"uid\""))
			#expect(text.contains("txn-123"))
			#expect(text.contains("name=\"info\""))
			#expect(text.contains("ZmFrZS1yZWNlaXB0"))
			#expect(text.contains("name=\"sig\""))
		}

		/// `action`'s `purchaseRestored` variant
		/// (`secretdjv3/TopUpAPIAccess.swift`'s `TopUpAction.purchaseRestored`).
		@Test func `sends action 2 for a restored purchase`() async throws {
			let recorder = RequestRecorder()
			let client = CreditsAPITests.makeClient(transport: FakeAPITransport(
				outcome: .success(Fixture.data("TopUpSuccess")),
				recorder: recorder,
			))

			_ = try await client.topUpNotify(
				userId: "u", vendor: .appleAppStore, action: .purchaseRestored,
				transactionId: "txn-123", receiptBase64: "cmVjZWlwdA==",
				credential: CreditsAPITests.credential,
			)

			let text = try bodyText(of: #require(recorder.requests.first))
			#expect(text.contains("name=\"action\"\r\n\r\n2\r\n"))
		}

		/// `TopUpSuccess.json`: `ReturnCode: 0` → credited
		/// (`secretdjv3/TopUpAPIAccess.swift`'s `TopUpReturnCodes.PV_OK`).
		@Test func `return code zero decodes as credited`() async throws {
			let client = CreditsAPITests.makeClient(
				transport: FakeAPITransport(outcome: .success(Fixture.data("TopUpSuccess"))),
			)

			let response = try await client.topUpNotify(
				userId: "u", vendor: .appleAppStore, action: .paymentReceived,
				transactionId: "t", receiptBase64: "r",
				credential: CreditsAPITests.credential,
			)

			#expect(response.payload == .credited(message: "It all worked"))
		}

		/// `TopUpFail.json`: `ReturnCode: 108` (positive, non-1) → a hard
		/// failure (`secretdjv3/TopUpAPIAccess.swift`'s
		/// `parseTopUpPaymentSuccess` `else` branch).
		@Test func `a positive non-one return code decodes as a hard failure`() async throws {
			let client = CreditsAPITests.makeClient(
				transport: FakeAPITransport(outcome: .success(Fixture.data("TopUpFail"))),
			)

			let response = try await client.topUpNotify(
				userId: "u", vendor: .appleAppStore, action: .paymentReceived,
				transactionId: "t", receiptBase64: "r",
				credential: CreditsAPITests.credential,
			)

			guard case .failure(let message) = response.payload else {
				Issue.record("expected .failure, got \(response.payload)")
				return
			}
			#expect(message.hasPrefix("Uh-oh! There was a hiccup with your top up..."))
		}

		/// `TopUpFailRetry.json`: `ReturnCode: -108` (negative) → retryable
		/// (`secretdjv3/TopUpAPIAccess.swift`'s `returnCode < 0` branch).
		@Test func `a negative return code decodes as retryable`() async throws {
			let client = CreditsAPITests.makeClient(
				transport: FakeAPITransport(outcome: .success(Fixture.data("TopUpFailRetry"))),
			)

			let response = try await client.topUpNotify(
				userId: "u", vendor: .appleAppStore, action: .paymentReceived,
				transactionId: "t", receiptBase64: "r",
				credential: CreditsAPITests.credential,
			)

			#expect(response.payload == .retryable)
		}

		/// // LIVE-CAPTURE: no legacy fixture carries `ReturnCode: 1`
		/// ("already processed" — `secretdjv3/TopUpAPIAccess.swift`'s
		/// `TopUpReturnCodes.PV_TRANSACTION_ALREADY_PROCESSED`); constructed
		/// from the documented contract.
		@Test func `return code one decodes as already processed`() async throws {
			let json = Data(#"{"Success": true, "Response": {"ReturnCode": 1, "Text": "Already processed"}}"#.utf8)
			let client = CreditsAPITests.makeClient(transport: FakeAPITransport(outcome: .success(json)))

			let response = try await client.topUpNotify(
				userId: "u", vendor: .appleAppStore, action: .paymentReceived,
				transactionId: "t", receiptBase64: "r",
				credential: CreditsAPITests.credential,
			)

			#expect(response.payload == .alreadyProcessed(message: "Already processed"))
		}
	}

	struct redeemjukeboxvoucher {
		/// `secretdjv3/TopUpAPIAccess.swift`'s `redeemCode`: `user`, `code`,
		/// optional `venue`.
		@Test func `sends the voucher code and signs the request`() async throws {
			let recorder = RequestRecorder()
			let client = CreditsAPITests.makeClient(transport: FakeAPITransport(
				outcome: .success(Fixture.data("RedeemVoucher")),
				recorder: recorder,
			))

			_ = try await client.redeemVoucher(
				userId: "00027786_c2eb9af2", venueId: "v", code: "FREESONG",
				credential: CreditsAPITests.credential,
			)

			let request = try #require(recorder.requests.first)
			#expect(request.url?.path == "/redeemjukeboxvoucher")
			let parameters = try percentEncodedParameters(of: request)
			#expect(parameters["user"] == "00027786_c2eb9af2")
			#expect(parameters["code"] == "FREESONG")
			#expect(parameters["venue"] == "v")
			#expect(parameters["sig"] != nil)
		}

		/// `RedeemVoucher.json`: `ReturnCode: 0` + confirmation `Text`.
		@Test func `decodes a successful redemption`() async throws {
			let client = CreditsAPITests.makeClient(
				transport: FakeAPITransport(outcome: .success(Fixture.data("RedeemVoucher"))),
			)

			let response = try await client.redeemVoucher(
				userId: "u", venueId: nil, code: "FREESONG",
				credential: CreditsAPITests.credential,
			)

			#expect(response.payload.returnCode == 0)
			#expect(response.payload.text == "Well done! You've just got yourself 5 extra songs. Use them wisely!")
		}

		/// `RedeemVoucherFail.json`: a non-zero `ReturnCode` (203) inside a
		/// `Success: true` envelope — the expired-code case.
		@Test func `decodes a failed redemption without throwing`() async throws {
			let client = CreditsAPITests.makeClient(
				transport: FakeAPITransport(outcome: .success(Fixture.data("RedeemVoucherFail"))),
			)

			let response = try await client.redeemVoucher(
				userId: "u", venueId: nil, code: "EXPIRED",
				credential: CreditsAPITests.credential,
			)

			#expect(response.payload.returnCode == 203)
			#expect(response.payload
				.text == "Sorry, the code you entered is passed its expiry date - you need fresh meat.")
		}
	}

	struct numpaidcredits {
		/// `secretdjv3/TopUpAPIAccess.swift`'s `numPaidCredits`: `user` only.
		@Test func `sends the user id and signs the request`() async throws {
			let recorder = RequestRecorder()
			let json = Data(#"{"Success": true, "Response": {"Text": "3"}}"#.utf8)
			let client = CreditsAPITests.makeClient(transport: FakeAPITransport(
				outcome: .success(json),
				recorder: recorder,
			))

			_ = try await client.numPaidCredits(userId: "00027786_c2eb9af2", credential: CreditsAPITests.credential)

			let request = try #require(recorder.requests.first)
			#expect(request.url?.path == "/numpaidcredits")
			let parameters = try percentEncodedParameters(of: request)
			#expect(parameters["user"] == "00027786_c2eb9af2")
			#expect(parameters["sig"] != nil)
		}

		/// `Live/NumPaidCredits.json` — a production `numpaidcredits`
		/// capture (S1's R2 live-capture pass) for an account with no paid
		/// credits, confirming the count-as-display-string contract
		/// (`secretdjv3/TopUpAPIAccess.swift`'s `parseNumPaidCreditsSuccess`).
		/// No legacy fixture existed for this endpoint. The live response
		/// also carries a `Response.NumCredits` field ``NumPaidCreditsPayload``
		/// doesn't model — harmless, since it only ever reads `Response.Text`,
		/// matching legacy's `parseNumPaidCreditsSuccess`.
		@Test func `decodes the credit count as a display string`() async throws {
			let client = CreditsAPITests.makeClient(
				transport: FakeAPITransport(outcome: .success(Fixture.liveData("NumPaidCredits"))),
			)

			let response = try await client.numPaidCredits(userId: "u", credential: CreditsAPITests.credential)

			#expect(
				response.payload
					.text == "You don't have any paid credits at the moment. Select a top-up to get some more.",
			)
		}
	}
}
