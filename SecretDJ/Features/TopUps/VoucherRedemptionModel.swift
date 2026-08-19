import Foundation
import Observability
import Observation
import SecretDJAPI

/// Drives the top-up screen's voucher-code bar
/// (`secretdjv3/AvailableTopUpsViewController.swift`'s
/// `redeemVoucherButtonTapped`): an empty/whitespace-only code shows the
/// same validation toast legacy does without ever reaching the network;
/// otherwise `redeemjukeboxvoucher`'s own response copy is toasted verbatim
/// (D11 — server copy renders as-delivered), on success or failure alike
/// (PLAN.md S6.7 SCOPE).
@MainActor
@Observable
final class VoucherRedemptionModel {
	var code = ""
	private(set) var isRedeeming = false
	private(set) var toastEvent: TopUpToastEvent?

	private let servicing: any TopUpsServicing
	private let sessionStore: SessionStore
	private let observability: ObservabilityPipeline

	init(servicing: any TopUpsServicing, sessionStore: SessionStore, observability: ObservabilityPipeline = .disabled) {
		self.servicing = servicing
		self.sessionStore = sessionStore
		self.observability = observability
	}

	func redeem() async {
		guard !isRedeeming else { return }

		let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !trimmed.isEmpty else {
			toastEvent = nextToast(Self.emptyCodeMessage)
			return
		}

		guard let userId = sessionStore.user?.personId, let credential = sessionStore.credential else { return }

		isRedeeming = true
		defer { isRedeeming = false }

		observability.interaction("redeemVoucher")

		do {
			let result = try await servicing.redeemVoucher(
				userId: userId,
				venueId: nil,
				code: trimmed,
				credential: credential,
			)
			if let rotatedToken = result.rotatedToken {
				sessionStore.rotateToken(rotatedToken)
			}

			toastEvent = nextToast(result.message ?? Self.genericFallback(succeeded: result.succeeded))
			if result.succeeded {
				code = ""
			}
		} catch {
			observability.report(error, category: "TopUps")
			toastEvent = nextToast(message(for: error))
		}
	}

	private func message(for error: TopUpsServiceError) -> String {
		if case .server(let message) = error, let message, !message.isEmpty {
			return message
		}
		return Self.connectionErrorMessage
	}

	private func nextToast(_ message: String) -> TopUpToastEvent {
		TopUpToastEvent(id: (toastEvent?.id ?? 0) + 1, message: message)
	}

	private static func genericFallback(succeeded: Bool) -> String {
		succeeded ? genericSuccessMessage : genericFailureMessage
	}

	private static var emptyCodeMessage: String {
		String(
			localized: "Please enter a voucher code",
			comment: "Toast shown when Redeem is tapped with an empty voucher-code field.",
		)
	}

	private static var genericSuccessMessage: String {
		String(
			localized: "Voucher redeemed!",
			comment: "Toast shown when a voucher code is redeemed successfully but the server sends no message of its own.",
		)
	}

	private static var genericFailureMessage: String {
		String(
			localized: "Sorry, that voucher code didn't work.",
			comment: "Toast shown when a voucher code is rejected and the server sends no message of its own.",
		)
	}

	private static var connectionErrorMessage: String {
		String(
			localized: "Sorry, we couldn't redeem that voucher.\n\nPlease check that you have a good connection to your cellular data or WiFi network.",
			comment: "Toast shown when redeeming a voucher code fails before reaching the server.",
		)
	}
}
