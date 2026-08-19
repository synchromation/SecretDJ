import Foundation
import Observability
import Observation
import SecretDJAPI

/// Started once at the composition root (`SecretDJApp`), replacing legacy's
/// resubmit-on-every-screen-appearance loop
/// (`secretdjv3/TopUpManager.swift`'s `resubmitPendingTopUps`, called from
/// half a dozen `viewDidAppear`s) with a single startup drain of StoreKit's
/// own durable unfinished-transaction queue: ``start()`` submits each
/// transaction ``ProductPurchasing/unfinishedTransactions()`` surfaces as a
/// fresh payment (`TopUpNotifyAction.paymentReceived`) and returns once that
/// snapshot is drained — StoreKit's own persistence (not a `UserDefaults`
/// pending list) is what makes anything missed this launch reappear on the
/// next one. ``restore()`` is "Restore Purchases": it triggers
/// ``ProductPurchasing/restorePurchases()``, then submits whatever
/// surfaces with the `purchaseRestored` flag; finding nothing queries
/// `numpaidcredits` and shows that count instead
/// (`secretdjv3/TopUpManager.swift`'s `onNoPurchasesToRestore`).
@MainActor
@Observable
final class TopUpTransactionListener {
	private(set) var isRestoring = false
	private(set) var toastEvent: TopUpToastEvent?

	private let purchasing: any ProductPurchasing
	private let servicing: any TopUpsServicing
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
		self.servicing = servicing
		submitter = TopUpNotifySubmitter(purchasing: purchasing, servicing: servicing)
		self.sessionStore = sessionStore
		self.observability = observability
	}

	/// Drains every transaction StoreKit currently considers unfinished,
	/// submitting each as a fresh payment. Returns once that snapshot
	/// completes (``ProductPurchasing/unfinishedTransactions()``'s doc
	/// comment) — call from a `.task { await listener.start() }` at the
	/// composition root so it doesn't block first render.
	func start() async {
		for await transaction in purchasing.unfinishedTransactions() {
			await handle(transaction, action: .paymentReceived)
		}
	}

	/// "Restore Purchases": syncs with the App Store, then submits whatever
	/// unfinished transactions surface as restored payments. Ignored while
	/// already restoring.
	func restore() async {
		guard !isRestoring else { return }
		isRestoring = true
		defer { isRestoring = false }

		observability.interaction("restorePurchases")

		do {
			try await purchasing.restorePurchases()
		} catch {
			observability.report(error, category: "TopUps")
			toastEvent = nextToast(Self.restoreFailedMessage)
			return
		}

		var restoredAny = false
		for await transaction in purchasing.unfinishedTransactions() {
			restoredAny = true
			await handle(transaction, action: .purchaseRestored)
		}

		guard !restoredAny else { return }

		await surfaceNothingToRestore()
	}

	private func handle(_ transaction: PurchasedTransaction, action: TopUpNotifyAction) async {
		guard let userId = sessionStore.user?.personId, let credential = sessionStore.credential else { return }

		let result = await submitter.submit(transaction, action: action, userId: userId, credential: credential)
		if let rotatedToken = result.rotatedToken {
			sessionStore.rotateToken(rotatedToken)
		}

		switch result.outcome {
		case .credited(let message):
			toastEvent = nextToast(message)

		case .alreadyProcessed(let message):
			toastEvent = nextToast(message)

		case .retryable:
			break

		case .failed(let message):
			toastEvent = nextToast(message.isEmpty ? Self.genericFailureMessage : message)
		}
	}

	private func surfaceNothingToRestore() async {
		guard let userId = sessionStore.user?.personId, let credential = sessionStore.credential else { return }

		do {
			let result = try await servicing.numPaidCredits(userId: userId, credential: credential)
			if let rotatedToken = result.rotatedToken {
				sessionStore.rotateToken(rotatedToken)
			}
			let creditsText = result.text ?? ""
			toastEvent = nextToast(creditsText.isEmpty ? Self
				.nothingToRestoreMessage : "\(Self.nothingToRestoreMessage)\n\n\(creditsText)")
		} catch {
			toastEvent = nextToast(Self.nothingToRestoreMessage)
		}
	}

	private func nextToast(_ message: String) -> TopUpToastEvent {
		TopUpToastEvent(id: (toastEvent?.id ?? 0) + 1, message: message)
	}

	private static var nothingToRestoreMessage: String {
		String(
			localized: "No purchases to restore.",
			comment: "Toast title shown after Restore Purchases finds nothing to restore, followed by the server's own paid-credit count.",
		)
	}

	private static var restoreFailedMessage: String {
		String(
			localized: "Sorry, we couldn't restore your purchases.\n\nPlease check that you have a good connection to your cellular data or WiFi network.",
			comment: "Toast shown when Restore Purchases fails before the App Store even responds.",
		)
	}

	private static var genericFailureMessage: String {
		String(
			localized: "Sorry, we couldn't complete that top-up.\n\nPlease try again.",
			comment: "Toast shown when a restored top-up's server verification hard-fails with no message of its own.",
		)
	}
}
