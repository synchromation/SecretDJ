import Foundation
import SecretDJDomain

/// `topupdetails`/`topupnotify`/`redeemjukeboxvoucher`/`numpaidcredits` —
/// the credits/top-up endpoints (LEGACY.md "Backend API and Spotify
/// integration" → endpoint catalog), typed over ``APIClient``. Ported from
/// `secretdjv3/TopUpAPIAccess.swift`. None of these appear in the legacy
/// sig-exclusion list, so every method here requires an ``APICredential``.
extension APIClient {
	/// `topupdetails` — a feed of ``SecretDJDomain/TopUp`` products
	/// (`secretdjv3/TopUpAPIAccess.swift`'s `topUpOptions`); `venue` is only
	/// sent when supplied, matching the legacy branch. `TopUp` items are
	/// already decodable from the returned ``SecretDJDomain/SectionList``
	/// (S1.1) — this just adds the typed request.
	public func topUpDetails(
		userId: String,
		venueId: String?,
		context: TopUpContext,
		vendor: Vendor,
		credential: APICredential,
	) async throws(APIError) -> APIResponse<SectionList> {
		var parameters = ["user": userId, "context": String(context.rawValue), "vendor": String(vendor.rawValue)]
		if let venueId {
			parameters["venue"] = venueId
		}
		return try await executeFeed(
			endpoint: "topupdetails",
			parameters: parameters,
			signed: true,
			credential: credential,
		)
	}

	/// `topupnotify` — submits a purchase confirmation for server-side
	/// verification (`secretdjv3/TopUpAPIAccess.swift`'s
	/// `verifyTransaction`), classifying the response's `ReturnCode` into a
	/// typed ``TopUpNotifyOutcome`` rather than throwing on a non-zero code.
	///
	/// Legacy POSTs `info` (the base64 receipt) as a plain multipart text
	/// field, with no filename/`Content-Type` of its own
	/// (`secretdjv3/PostRequestProvider.swift`'s `postRequest`) — this
	/// reuses ``APIClient/execute(multipartEndpoint:parameters:fileFieldName:filename:mimeType:fileData:credential:decodingPayloadAs:)``
	/// instead (the same builder `newavatar` uses), sending `info` as that
	/// call's one file part. The field name on the wire (`"info"`) is
	/// identical either way; the two extra multipart headers that shape adds
	/// are inert to a standards-compliant multipart parser, so this doesn't
	/// change what the server receives.
	public func topUpNotify(
		userId: String,
		vendor: Vendor,
		action: TopUpNotifyAction,
		transactionId: String,
		receiptBase64: String,
		credential: APICredential,
	) async throws(APIError) -> APIResponse<TopUpNotifyOutcome> {
		let response = try await execute(
			multipartEndpoint: "topupnotify",
			parameters: [
				"user": userId,
				"vendor": String(vendor.rawValue),
				"action": String(action.rawValue),
				"uid": transactionId,
			],
			fileFieldName: "info",
			filename: "receipt.txt",
			mimeType: "text/plain",
			fileData: Data(receiptBase64.utf8),
			credential: credential,
			decodingPayloadAs: APIActionPayload.self,
		)
		return APIResponse(
			payload: TopUpNotifyOutcome(
				returnCode: response.payload.response.returnCode,
				message: response.payload.response.text,
			),
			rotatedToken: response.rotatedToken,
		)
	}

	/// `redeemjukeboxvoucher` — ported from
	/// `secretdjv3/TopUpAPIAccess.swift`'s `redeemCode`; `venue` is only sent
	/// when supplied.
	public func redeemVoucher(
		userId: String,
		venueId: String?,
		code: String,
		credential: APICredential,
	) async throws(APIError) -> APIResponse<APIActionResponse> {
		var parameters = ["user": userId, "code": code]
		if let venueId {
			parameters["venue"] = venueId
		}
		let response = try await execute(
			endpoint: "redeemjukeboxvoucher",
			parameters: parameters,
			signed: true,
			credential: credential,
			decodingPayloadAs: APIActionPayload.self,
		)
		return APIResponse(payload: response.payload.response, rotatedToken: response.rotatedToken)
	}

	/// `numpaidcredits` — ported from `secretdjv3/TopUpAPIAccess.swift`'s
	/// `numPaidCredits`. The response carries only a display-string count
	/// (LEGACY.md's catalog: "`Response.Text` (count as display string)"),
	/// with no `ReturnCode` alongside it — unlike every other action
	/// endpoint in this package, so this doesn't reuse ``APIActionPayload``.
	/// Never parsed to `Int` client-side, matching
	/// `secretdjv3/TopUpAPIAccess.swift`'s `parseNumPaidCreditsSuccess`.
	public func numPaidCredits(
		userId: String,
		credential: APICredential,
	) async throws(APIError) -> APIResponse<NumPaidCreditsPayload> {
		try await execute(
			endpoint: "numpaidcredits",
			parameters: ["user": userId],
			signed: true,
			credential: credential,
			decodingPayloadAs: NumPaidCreditsPayload.self,
		)
	}
}

/// `numpaidcredits`'s response body: the display-string credit count
/// (`secretdjv3/TopUpAPIAccess.swift`'s `parseNumPaidCreditsSuccess` only
/// ever reads `Response.Text`).
public struct NumPaidCreditsPayload: Sendable, Hashable, Decodable {
	public let text: String?

	private enum CodingKeys: String, CodingKey {
		case response = "Response"
	}

	private struct ResponseWire: Decodable {
		let text: String?

		private enum CodingKeys: String, CodingKey {
			case text = "Text"
		}
	}

	public init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		let response = try container.decode(ResponseWire.self, forKey: .response)
		text = response.text
	}
}

/// `topupdetails`'s `context` parameter
/// (`secretdjv3/TopUpAPIAccess.swift`'s `TopUpContext`).
public enum TopUpContext: Int, Sendable {
	case insertCoin = 0
	case noCredits = 1
}

/// `topupnotify`'s `action` parameter — a fresh purchase versus a restored
/// one (`secretdjv3/TopUpAPIAccess.swift`'s `TopUpAction`).
public enum TopUpNotifyAction: Int, Sendable {
	case paymentReceived = 1
	case purchaseRestored = 2
}

/// The outcome of a `topupnotify` call, classified from its `ReturnCode`
/// (`secretdjv3/TopUpAPIAccess.swift`'s `parseTopUpPaymentSuccess`):
/// `0` credits the account, `1` means the client already submitted this
/// transaction and the server silently no-ops, negative codes are
/// transient and safe to resubmit, everything else is a hard failure.
public enum TopUpNotifyOutcome: Sendable, Hashable {
	/// `ReturnCode == 0`: the purchase was credited.
	case credited(message: String)
	/// `ReturnCode == 1`: already verified by an earlier submission — the
	/// caller's pending-top-up bookkeeping (LEGACY.md's `PendingTopUps`)
	/// should drop this transaction, not resubmit it.
	case alreadyProcessed(message: String)
	/// `ReturnCode < 0`: a transient failure safe to resubmit.
	case retryable
	/// Any other positive `ReturnCode`: a server-worded hard failure.
	case failure(message: String)

	public init(returnCode: Int, message: String?) {
		switch returnCode {
		case 0:
			self = .credited(message: message ?? "")
		case 1:
			self = .alreadyProcessed(message: message ?? "")
		case ..<0:
			self = .retryable
		default:
			self = .failure(message: message ?? "")
		}
	}
}
