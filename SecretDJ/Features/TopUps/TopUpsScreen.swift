import DesignSystem
import FeedUI
import Observability
import SecretDJAPI
import SecretDJDomain
import SwiftUI

/// The credits top-up screen (`secretdjv3/AvailableTopUpsViewController.swift`'s
/// "Get more songs"): a `topupdetails` feed of ``SecretDJDomain/TopUp``
/// products rendered via ``DesignSystem/TopUpRowCell`` (through
/// ``FeedUI/FeedCellProps/topUp(_:)``), a voucher-redemption bar, and a
/// Restore Purchases button. `context` (insert-coin toolbar button vs the
/// out-of-credits funnel) is threaded straight into `topupdetails` — the
/// server's own response is what varies the copy per context, this screen
/// carries no context-specific text of its own.
///
/// Tapping a top-up row is deliberately **not** routed through
/// ``FeedUI/FeedActionRouter`` (its own doc comment: "starts a StoreKit
/// purchase... out of scope for S3.3") — this screen intercepts `.topUp`
/// taps directly, which is why it builds ``FeedUI/FeedView``'s load-state
/// switch itself rather than reusing ``FeedUI/FeedScreen`` wholesale (that
/// convenience wrapper's `onOutcome` never fires for a tap
/// ``FeedUI/FeedActionRouter`` resolves to `nil`).
struct TopUpsScreen: View {
	let toastQueue: ToastQueue
	/// Owns "Restore Purchases" and the startup unfinished-transaction
	/// drain — constructed once at the composition root
	/// (``TopUpTransactionListener``'s doc comment), not per screen
	/// presentation.
	let listener: TopUpTransactionListener
	let observability: ObservabilityPipeline

	@State private var feedModel: FeedScreenModel
	@State private var purchaseModel: TopUpPurchaseModel
	@State private var voucherModel: VoucherRedemptionModel
	@FocusState private var isVoucherFieldFocused: Bool
	@Environment(\.dynamicTypeSize) private var dynamicTypeSize

	/// `loader`/`productPurchasing`/`topUpsServicing` are already-built
	/// dependencies (mirrors ``VenueScreen``'s `loader:`/`likeToggling:`/
	/// `promotionEngaging:` parameters) rather than a raw `APIClient` this
	/// screen would build its own adapters from — keeps every dependency
	/// swappable for a preview fixture.
	init(
		loader: any FeedLoading,
		sessionStore: SessionStore,
		toastQueue: ToastQueue,
		listener: TopUpTransactionListener,
		productPurchasing: any ProductPurchasing,
		topUpsServicing: any TopUpsServicing,
		observability: ObservabilityPipeline = .disabled,
	) {
		self.toastQueue = toastQueue
		self.listener = listener
		self.observability = observability

		_feedModel = State(initialValue: FeedScreenModel(
			loader: loader,
			router: FeedActionRouter(installedApps: URLSchemeInstalledApps()),
			configuration: FeedConfiguration(autoRefresh: nil, paginationEnabled: false, changePolicy: .surfaceChange),
		))
		_purchaseModel = State(initialValue: TopUpPurchaseModel(
			purchasing: productPurchasing,
			servicing: topUpsServicing,
			sessionStore: sessionStore,
			observability: observability,
		))
		_voucherModel = State(initialValue: VoucherRedemptionModel(
			servicing: topUpsServicing,
			sessionStore: sessionStore,
			observability: observability,
		))
	}

	var body: some View {
		VStack(spacing: 0) {
			voucherBar
			content
			restoreBar
		}
		.frame(maxWidth: .infinity, maxHeight: .infinity)
		.background(Theme.ColorRole.background.color)
		.navigationTitle(Text("Get More Songs", comment: "Navigation title of the credits top-up screen."))
		.disabled(purchaseModel.isPurchasing || listener.isRestoring || voucherModel.isRedeeming)
		.task { await feedModel.start() }
		.onDisappear { feedModel.stop() }
		.onChange(of: purchaseModel.toastEvent) { _, event in showToast(event) }
		.onChange(of: voucherModel.toastEvent) { _, event in showToast(event) }
		.onChange(of: listener.toastEvent) { _, event in showToast(event) }
		.tracksScreen("TopUps")
	}

	@ViewBuilder
	private var content: some View {
		switch feedModel.phase {
		case .loading:
			ProgressSurface()
				.frame(maxWidth: .infinity, maxHeight: .infinity)

		case .empty:
			refreshableScroll {
				EmptyStateView(
					systemImage: Theme.Icon.topUp.systemName,
					title: Self.emptyTitle,
					message: Self.emptyMessage,
				)
			}

		case .error(let offline):
			refreshableScroll {
				ErrorStateView(
					systemImage: offline ? "wifi.slash" : "exclamationmark.triangle",
					title: offline ? Self.offlineTitle : Self.errorTitle,
					message: offline ? Self.offlineMessage : Self.errorMessage,
					retryTitle: Self.retryTitle,
					retryAction: { Task { await feedModel.refresh() } },
				)
			}

		case .loaded:
			FeedView(
				sections: feedModel.visibleSections,
				generation: feedModel.generation,
				onItemTap: handleTap,
				onApproachingEnd: { Task { await feedModel.loadNextPage() } },
			)
			.refreshable { await feedModel.refresh() }
		}
	}

	private var voucherBar: some View {
		VStack(alignment: .leading, spacing: Spacing.small) {
			Text("Got a voucher code?", comment: "Header above the voucher-code redemption bar on the top-up screen.")
				.font(Theme.TextStyle.sectionHeader.font)
				.foregroundStyle(Theme.ColorRole.primaryText.color)

			// A horizontal field-plus-button row can't fit both at
			// accessibility text sizes — stack them instead (accessibility
			// skill: "horizontal control rows become vertical stacks").
			if dynamicTypeSize.isAccessibilitySize {
				VStack(alignment: .leading, spacing: Spacing.small) {
					voucherField
					redeemButton
				}
			} else {
				HStack(spacing: Spacing.small) {
					voucherField
					redeemButton
				}
			}
		}
		.padding(Spacing.medium)
	}

	private var voucherField: some View {
		TextField(
			"Enter a voucher code",
			text: Binding(get: { voucherModel.code }, set: { voucherModel.code = $0 }),
		)
		.textInputAutocapitalization(.characters)
		.autocorrectionDisabled()
		.focused($isVoucherFieldFocused)
		.submitLabel(.done)
		.onSubmit(redeemVoucher)
		.padding()
		.frame(minHeight: 44)
		.background(Theme.ColorRole.cellSurface.color, in: .rect(cornerRadius: 12))
	}

	private var redeemButton: some View {
		Button(action: redeemVoucher) {
			Group {
				if voucherModel.isRedeeming {
					Text("REDEEMING...", comment: "Redeem button title while a voucher code is being submitted.")
				} else {
					Text("REDEEM", comment: "Button that submits the voucher-code field on the top-up screen.")
				}
			}
		}
		.buttonStyle(.primary)
		.disabled(voucherModel.isRedeeming)
	}

	private var restoreBar: some View {
		Button(action: restorePurchases) {
			Group {
				if listener.isRestoring {
					Text("RESTORING...", comment: "Restore Purchases button title while a restore is in progress.")
				} else {
					Text(
						"Restore Purchases",
						comment: "Button that re-triggers server credit for any interrupted App Store purchase.",
					)
				}
			}
			.frame(maxWidth: .infinity)
		}
		.buttonStyle(.secondary)
		.disabled(listener.isRestoring)
		.padding(Spacing.medium)
	}

	/// `topupdetails` only ever returns `topUp` items (LEGACY.md's endpoint
	/// catalog), so every real tap lands in the first branch; the fallback
	/// is a defensive no-op rather than a crash for a payload shape this
	/// screen was never designed to show.
	private func handleTap(_ item: FeedDisplayItem) {
		guard case .topUp(let topUp) = item.item else { return }
		Task { await purchaseModel.purchase(topUp) }
	}

	private func redeemVoucher() {
		isVoucherFieldFocused = false
		Task { await voucherModel.redeem() }
	}

	private func restorePurchases() {
		Task { await listener.restore() }
	}

	private func showToast(_ event: TopUpToastEvent?) {
		guard let event else { return }
		toastQueue.enqueue(ToastItem(message: event.message))
	}

	/// `FeedScreen`'s own `.refreshable` scroll wrapper for the empty/error
	/// surfaces, which don't fill the screen or scroll on their own —
	/// duplicated here rather than imported since it's `private` on
	/// `FeedUI/FeedScreen`.
	private func refreshableScroll(@ViewBuilder content: () -> some View) -> some View {
		ScrollView {
			content()
				.frame(maxWidth: .infinity)
		}
		.refreshable { await feedModel.refresh() }
	}

	private static var emptyTitle: Text {
		Text("Nothing Here Yet", comment: "Title shown on the top-up screen when the server has no products to offer.")
	}

	private static var emptyMessage: Text {
		Text(
			"There's nothing to buy right now — check back soon.",
			comment: "Body shown on the top-up screen when the server has no products to offer.",
		)
	}

	private static var errorTitle: Text {
		Text("Something Went Wrong", comment: "Title shown on the top-up screen when it fails to load.")
	}

	private static var errorMessage: Text {
		Text(
			"Sorry, we couldn't load the top-up options.\n\nPlease check that you have a good connection to your cellular data or WiFi network.",
			comment: "Body shown on the top-up screen when it fails to load.",
		)
	}

	private static var offlineTitle: Text {
		Text("You're Offline", comment: "Title shown on the top-up screen when the device has no internet connection.")
	}

	private static var offlineMessage: Text {
		Text(
			"Check your connection and try again.",
			comment: "Body shown on the top-up screen when the device has no internet connection.",
		)
	}

	private static var retryTitle: Text {
		Text("Try Again", comment: "Button that retries loading the top-up screen after a failure.")
	}
}

extension FeedActionOutcome.TopUpContext {
	/// Maps FeedUI's own `TopUpContext` (kept separate so FeedUI takes no
	/// dependency on `SecretDJAPI` — its own doc comment) to the
	/// `topupdetails` request parameter.
	var apiContext: TopUpContext {
		switch self {
		case .insertCoin: .insertCoin
		case .noCredits: .noCredits
		}
	}
}

// MARK: - Previews

#Preview("Loaded") {
	NavigationStack {
		TopUpsScreen(
			loader: PreviewTopUpsLoading.loaded(),
			sessionStore: PreviewSessionStore.signedIn(),
			toastQueue: ToastQueue(),
			listener: TopUpTransactionListener(
				purchasing: FakeProductPurchasing(),
				servicing: InMemoryTopUpsServicing(),
				sessionStore: PreviewSessionStore.signedIn(),
			),
			productPurchasing: FakeProductPurchasing(),
			topUpsServicing: InMemoryTopUpsServicing(),
		)
	}
}

#Preview("Empty") {
	NavigationStack {
		TopUpsScreen(
			loader: PreviewTopUpsLoading.empty(),
			sessionStore: PreviewSessionStore.signedIn(),
			toastQueue: ToastQueue(),
			listener: TopUpTransactionListener(
				purchasing: FakeProductPurchasing(),
				servicing: InMemoryTopUpsServicing(),
				sessionStore: PreviewSessionStore.signedIn(),
			),
			productPurchasing: FakeProductPurchasing(),
			topUpsServicing: InMemoryTopUpsServicing(),
		)
	}
}

#Preview("Accessibility text size") {
	NavigationStack {
		TopUpsScreen(
			loader: PreviewTopUpsLoading.loaded(),
			sessionStore: PreviewSessionStore.signedIn(),
			toastQueue: ToastQueue(),
			listener: TopUpTransactionListener(
				purchasing: FakeProductPurchasing(),
				servicing: InMemoryTopUpsServicing(),
				sessionStore: PreviewSessionStore.signedIn(),
			),
			productPurchasing: FakeProductPurchasing(),
			topUpsServicing: InMemoryTopUpsServicing(),
		)
	}
	.environment(\.dynamicTypeSize, .accessibility5)
}
