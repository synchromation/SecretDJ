import Foundation
import Observability
import Observation
import SecretDJAPI
import SecretDJDomain

/// Drives one top-up row's purchase (PLAN.md S6.7 SCOPE): resolve the
/// StoreKit product by the feed item's SKU, purchase, then submit via
/// `topupnotify` through ``TopUpNotifySubmitter``. A typed pre-payment
/// failure (the SKU can't be resolved, or StoreKit's own purchase call
/// fails) always pairs with the tone guide's load-bearing "No payment was
/// taken." phrase, since no money has changed hands yet; a post-payment
/// `topupnotify` failure never does, since StoreKit already took the money
/// by the time that call runs (``TopUpNotifySubmitter``'s doc comment).
@MainActor
@Observable
final class TopUpPurchaseModel {
	private(set) var isPurchasing = false
	private(set) var toastEvent: TopUpToastEvent?

	private let purchasing: any ProductPurchasing
	private let submitter: TopUpNotifySubmitter
	private let sessionStore: SessionStore
	private let observability: ObservabilityPipeline

	init(
		purchasing: any ProductPurchasing,
		servicing: any TopUpsServicing,
		sessionStore: SessionStore,
		observability: ObservabilityPipeline = .disabled,
	) {
		self.purchasing = purchasing
		submitter = TopUpNotifySubmitter(purchasing: purchasing, servicing: servicing)
		self.sessionStore = sessionStore
		self.observability = observability
	}

	func purchase(_ topUp: TopUp) async {
		guard !isPurchasing else { return }
		guard let userId = sessionStore.user?.personId, let credential = sessionStore.credential else { return }

		isPurchasing = true
		defer { isPurchasing = false }

		observability.interaction("purchaseTopUp")
		observability.track(TopUpsEvent.purchaseInitiated)

		do {
			let product = try await purchasing.product(for: topUp.sku)
			let result = try await purchasing.purchase(product)

			switch result {
			case .success(let transaction):
				await handle(transaction, userId: userId, credential: credential)

			case .userCancelled,
			     .pending:
				break
			}
		} catch {
			observability.report(error, category: "TopUps")
			observability.track(TopUpsEvent.purchaseFailed)
			toastEvent = nextToast(Self.paymentFailedMessage)
		}
	}

	private func handle(_ transaction: PurchasedTransaction, userId: String, credential: APICredential) async {
		let result = await submitter.submit(
			transaction,
			action: .paymentReceived,
			userId: userId,
			credential: credential,
		)
		if let rotatedToken = result.rotatedToken {
			sessionStore.rotateToken(rotatedToken)
		}

		switch result.outcome {
		case .credited(let message):
			observability.track(TopUpsEvent.purchaseCompleted)
			toastEvent = nextToast(message)

		case .alreadyProcessed(let message):
			toastEvent = nextToast(message)

		case .retryable:
			break

		case .failed(let message):
			observability.track(TopUpsEvent.purchaseFailed)
			toastEvent = nextToast(message.isEmpty ? Self.genericFailureMessage : message)
		}
	}

	private func nextToast(_ message: String) -> TopUpToastEvent {
		TopUpToastEvent(id: (toastEvent?.id ?? 0) + 1, message: message)
	}

	/// The tone guide's load-bearing phrase, verbatim — only ever shown
	/// before any payment could have been taken (LEGACY.md/localization
	/// skill: "reused verbatim, with fixed renderings per language").
	private static var paymentFailedMessage: String {
		String(
			localized: "Sorry, that purchase failed.\n\nNo payment was taken.",
			comment: "Toast shown when a top-up purchase fails before any payment is taken — the SKU couldn't be resolved, or the App Store's own purchase sheet failed.",
		)
	}

	private static var genericFailureMessage: String {
		String(
			localized: "Sorry, we couldn't complete that top-up.\n\nPlease try again.",
			comment: "Toast shown when a top-up purchase succeeds with the App Store but the server rejects it with no message of its own.",
		)
	}
}
