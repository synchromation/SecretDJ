import SecretDJAPI
import SecretDJDomain

/// One recorded call to ``InMemoryTopUpsServicing/notifyPurchase``.
struct NotifyPurchaseInvocation: Equatable {
	let userId: String
	let vendor: Vendor
	let action: TopUpNotifyAction
	let transactionId: String
	let receiptBase64: String
	let credential: APICredential
}

/// One recorded call to ``InMemoryTopUpsServicing/redeemVoucher``.
struct RedeemVoucherInvocation: Equatable {
	let userId: String
	let venueId: String?
	let code: String
	let credential: APICredential
}

/// One recorded call to ``InMemoryTopUpsServicing/numPaidCredits``.
struct NumPaidCreditsInvocation: Equatable {
	let userId: String
	let credential: APICredential
}

/// A scriptable ``TopUpsServicing`` fake for tests and previews — never
/// touches the network. Each call records its arguments and returns the
/// result configured for it, so tests can both seed outcomes and assert on
/// what was sent.
@MainActor
final class InMemoryTopUpsServicing: TopUpsServicing {
	var notifyPurchaseResult: Result<TopUpNotifyServiceResult, TopUpsServiceError>
	var redeemVoucherResult: Result<VoucherRedemptionServiceResult, TopUpsServiceError>
	var numPaidCreditsResult: Result<NumPaidCreditsServiceResult, TopUpsServiceError>

	private(set) var notifyPurchaseInvocations: [NotifyPurchaseInvocation] = []
	private(set) var redeemVoucherInvocations: [RedeemVoucherInvocation] = []
	private(set) var numPaidCreditsInvocations: [NumPaidCreditsInvocation] = []

	init(
		notifyPurchaseResult: Result<TopUpNotifyServiceResult, TopUpsServiceError> = .failure(.connection),
		redeemVoucherResult: Result<VoucherRedemptionServiceResult, TopUpsServiceError> = .failure(.connection),
		numPaidCreditsResult: Result<NumPaidCreditsServiceResult, TopUpsServiceError> = .failure(.connection),
	) {
		self.notifyPurchaseResult = notifyPurchaseResult
		self.redeemVoucherResult = redeemVoucherResult
		self.numPaidCreditsResult = numPaidCreditsResult
	}

	func notifyPurchase(
		userId: String,
		vendor: Vendor,
		action: TopUpNotifyAction,
		transactionId: String,
		receiptBase64: String,
		credential: APICredential,
	) async throws(TopUpsServiceError) -> TopUpNotifyServiceResult {
		notifyPurchaseInvocations.append(NotifyPurchaseInvocation(
			userId: userId,
			vendor: vendor,
			action: action,
			transactionId: transactionId,
			receiptBase64: receiptBase64,
			credential: credential,
		))
		switch notifyPurchaseResult {
		case .success(let result): return result
		case .failure(let error): throw error
		}
	}

	func redeemVoucher(
		userId: String,
		venueId: String?,
		code: String,
		credential: APICredential,
	) async throws(TopUpsServiceError) -> VoucherRedemptionServiceResult {
		redeemVoucherInvocations.append(RedeemVoucherInvocation(
			userId: userId,
			venueId: venueId,
			code: code,
			credential: credential,
		))
		switch redeemVoucherResult {
		case .success(let result): return result
		case .failure(let error): throw error
		}
	}

	func numPaidCredits(
		userId: String,
		credential: APICredential,
	) async throws(TopUpsServiceError) -> NumPaidCreditsServiceResult {
		numPaidCreditsInvocations.append(NumPaidCreditsInvocation(userId: userId, credential: credential))
		switch numPaidCreditsResult {
		case .success(let result): return result
		case .failure(let error): throw error
		}
	}
}
