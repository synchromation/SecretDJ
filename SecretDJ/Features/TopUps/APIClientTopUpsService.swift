import Foundation
import SecretDJAPI
import SecretDJDomain

/// The production ``TopUpsServicing``: calls straight through to
/// ``SecretDJAPI/APIClient``'s credits endpoints, mapping ``APIError`` to
/// this feature's own ``TopUpsServiceError``.
struct APIClientTopUpsService: TopUpsServicing {
	private let client: APIClient

	init(client: APIClient) {
		self.client = client
	}

	func notifyPurchase(
		userId: String,
		vendor: Vendor,
		action: TopUpNotifyAction,
		transactionId: String,
		receiptBase64: String,
		credential: APICredential,
	) async throws(TopUpsServiceError) -> TopUpNotifyServiceResult {
		do {
			let response = try await client.topUpNotify(
				userId: userId,
				vendor: vendor,
				action: action,
				transactionId: transactionId,
				receiptBase64: receiptBase64,
				credential: credential,
			)
			return TopUpNotifyServiceResult(outcome: response.payload, rotatedToken: response.rotatedToken)
		} catch {
			throw TopUpsServiceError(error)
		}
	}

	func redeemVoucher(
		userId: String,
		venueId: String?,
		code: String,
		credential: APICredential,
	) async throws(TopUpsServiceError) -> VoucherRedemptionServiceResult {
		do {
			let response = try await client.redeemVoucher(
				userId: userId,
				venueId: venueId,
				code: code,
				credential: credential,
			)
			return VoucherRedemptionServiceResult(
				succeeded: response.payload.returnCode == 0,
				message: response.payload.text,
				rotatedToken: response.rotatedToken,
			)
		} catch {
			throw TopUpsServiceError(error)
		}
	}

	func numPaidCredits(
		userId: String,
		credential: APICredential,
	) async throws(TopUpsServiceError) -> NumPaidCreditsServiceResult {
		do {
			let response = try await client.numPaidCredits(userId: userId, credential: credential)
			return NumPaidCreditsServiceResult(text: response.payload.text, rotatedToken: response.rotatedToken)
		} catch {
			throw TopUpsServiceError(error)
		}
	}
}
