import Observability
import SecretDJAPI
import Testing

@testable import SecretDJ

/// ``VoucherRedemptionModel`` — the voucher-code bar's `redeemjukeboxvoucher`
/// call (`secretdjv3/AvailableTopUpsViewController.swift`'s
/// `redeemVoucherButtonTapped`): an empty code toasts the same validation
/// message legacy shows without ever reaching the network, otherwise the
/// server's own response copy is toasted verbatim (PLAN.md S6.7 SCOPE).
@MainActor
enum VoucherRedemptionModelTests {
	struct `Starting up` {
		@Test func `starts idle, with an empty code and no toast`() {
			let model = makeModel()

			#expect(model.code.isEmpty)
			#expect(!model.isRedeeming)
			#expect(model.toastEvent == nil)
		}
	}

	struct `Redeeming, with an empty code` {
		@Test func `toasts the validation message without calling the server`() async {
			let servicing = InMemoryTopUpsServicing()
			let model = makeModel(servicing: servicing)

			await model.redeem()

			#expect(model.toastEvent?.message == "Please enter a voucher code")
			#expect(servicing.redeemVoucherInvocations.isEmpty)
		}

		@Test func `toasts the same validation message for whitespace-only input`() async {
			let servicing = InMemoryTopUpsServicing()
			let model = makeModel(servicing: servicing)
			model.code = "   "

			await model.redeem()

			#expect(model.toastEvent?.message == "Please enter a voucher code")
			#expect(servicing.redeemVoucherInvocations.isEmpty)
		}
	}

	struct `Redeeming, on success` {
		@Test func `sends the trimmed code with the signed-in user's id and credential`() async throws {
			let servicing = InMemoryTopUpsServicing(
				redeemVoucherResult: .success(VoucherRedemptionServiceResult(
					succeeded: true,
					message: "You've got 10 free credits!",
					rotatedToken: nil,
				)),
			)
			let model = makeModel(servicing: servicing)
			model.code = "  SUMMER10  "

			await model.redeem()

			let invocation = try #require(servicing.redeemVoucherInvocations.first)
			#expect(invocation.userId == "9")
			#expect(invocation.code == "SUMMER10")
			#expect(invocation.credential == APICredential(token: "tok", passwordHash: "hash"))
		}

		@Test func `toasts the server's own message`() async {
			let servicing = InMemoryTopUpsServicing(
				redeemVoucherResult: .success(VoucherRedemptionServiceResult(
					succeeded: true,
					message: "You've got 10 free credits!",
					rotatedToken: nil,
				)),
			)
			let model = makeModel(servicing: servicing)
			model.code = "SUMMER10"

			await model.redeem()

			#expect(model.toastEvent?.message == "You've got 10 free credits!")
		}

		@Test func `clears the code field`() async {
			let servicing = InMemoryTopUpsServicing(
				redeemVoucherResult: .success(VoucherRedemptionServiceResult(
					succeeded: true,
					message: "Nice",
					rotatedToken: nil,
				)),
			)
			let model = makeModel(servicing: servicing)
			model.code = "SUMMER10"

			await model.redeem()

			#expect(model.code.isEmpty)
		}

		@Test func `rotates the session's token when the outcome carries one`() async {
			let servicing = InMemoryTopUpsServicing(
				redeemVoucherResult: .success(VoucherRedemptionServiceResult(
					succeeded: true,
					message: "Nice",
					rotatedToken: "new-tok",
				)),
			)
			let sessionStore = makeSessionStore()
			let model = makeModel(servicing: servicing, sessionStore: sessionStore)
			model.code = "SUMMER10"

			await model.redeem()

			#expect(sessionStore.credential == APICredential(token: "new-tok", passwordHash: "hash"))
		}
	}

	struct `Redeeming, on a server-rejected code` {
		@Test func `toasts the server's own message and leaves the code field untouched`() async {
			let servicing = InMemoryTopUpsServicing(
				redeemVoucherResult: .success(VoucherRedemptionServiceResult(
					succeeded: false,
					message: "Sorry, that code has expired",
					rotatedToken: nil,
				)),
			)
			let model = makeModel(servicing: servicing)
			model.code = "EXPIRED"

			await model.redeem()

			#expect(model.toastEvent?.message == "Sorry, that code has expired")
			#expect(model.code == "EXPIRED")
		}
	}

	struct `Redeeming, on a connection failure` {
		@Test func `toasts a fallback message`() async {
			let servicing = InMemoryTopUpsServicing(redeemVoucherResult: .failure(.connection))
			let model = makeModel(servicing: servicing)
			model.code = "SUMMER10"

			await model.redeem()

			#expect(model.toastEvent != nil)
			#expect(model.code == "SUMMER10")
		}
	}

	struct `Redeeming, guards` {
		@Test func `does nothing when no session is signed in`() async {
			let servicing = InMemoryTopUpsServicing()
			let model = makeModel(servicing: servicing, sessionStore: makeSignedOutSessionStore())
			model.code = "SUMMER10"

			await model.redeem()

			#expect(servicing.redeemVoucherInvocations.isEmpty)
		}
	}

	struct Instrumentation {
		@Test func `breadcrumbs the redemption attempt, without an analytics event`() async {
			let servicing = InMemoryTopUpsServicing(
				redeemVoucherResult: .success(VoucherRedemptionServiceResult(
					succeeded: true,
					message: "Nice",
					rotatedToken: nil,
				)),
			)
			let recorder = RecordingDestination()
			let model = makeModel(servicing: servicing, observability: ObservabilityPipeline(destinations: [recorder]))
			model.code = "SUMMER10"

			await model.redeem()

			#expect(recorder.breadcrumbs.contains { if case .interaction = $0 { true } else { false } })
			#expect(recorder.analytics.isEmpty)
		}
	}
}

// MARK: - Fixtures

@MainActor
private func makeSessionStore() -> SessionStore {
	let store = SessionStore(snapshotStore: InMemorySessionSnapshotStore(), credentialStore: InMemoryCredentialStore())
	store.signIn(
		user: SessionUser(personId: "9", screenName: "TurboTim"),
		venue: nil,
		credential: APICredential(token: "tok", passwordHash: "hash"),
	)
	return store
}

@MainActor
private func makeSignedOutSessionStore() -> SessionStore {
	SessionStore(snapshotStore: InMemorySessionSnapshotStore(), credentialStore: InMemoryCredentialStore())
}

@MainActor
private func makeModel(
	servicing: InMemoryTopUpsServicing = InMemoryTopUpsServicing(),
	sessionStore: SessionStore? = nil,
	observability: ObservabilityPipeline = .disabled,
) -> VoucherRedemptionModel {
	VoucherRedemptionModel(
		servicing: servicing,
		sessionStore: sessionStore ?? makeSessionStore(),
		observability: observability,
	)
}
