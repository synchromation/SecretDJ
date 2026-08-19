import Foundation
import Observability
import SecretDJAPI
import Testing

@testable import SecretDJ

@MainActor
enum AccountModelTests {
	private static func makeSessionStore() -> SessionStore {
		let store = SessionStore(
			snapshotStore: InMemorySessionSnapshotStore(),
			credentialStore: InMemoryCredentialStore(),
		)
		store.signIn(
			user: SessionUser(personId: "9", screenName: "TurboTim"),
			venue: nil,
			credential: APICredential(token: "tok", passwordHash: "hash"),
		)
		return store
	}

	private static func makeModel(
		accountService: InMemoryAccountService = InMemoryAccountService(),
		sessionStore: SessionStore? = nil,
		observability: ObservabilityPipeline = .disabled,
	) -> (model: AccountModel, sessionStore: SessionStore) {
		let sessionStore = sessionStore ?? makeSessionStore()
		let model = AccountModel(
			personId: "9",
			credential: APICredential(token: "tok", passwordHash: "hash"),
			accountService: accountService,
			sessionStore: sessionStore,
			observability: observability,
		)
		return (model, sessionStore)
	}

	struct `Starting up` {
		@Test func `has made no deletion request yet`() {
			let (model, _) = AccountModelTests.makeModel()

			#expect(model.isDeletionRequested == false)
			#expect(model.isSubmittingDeletion == false)
			#expect(model.errorMessage == nil)
		}
	}

	struct `Requesting deletion` {
		@Test func `calls requestDeleteAccount with the right userId and credential`() async {
			let service = InMemoryAccountService(
				requestDeleteAccountResult: .success(AccountDeletionOutcome(message: "Your account will be deleted.")),
			)
			let (model, _) = AccountModelTests.makeModel(accountService: service)

			await model.requestDeletion()

			let invocation = try? #require(service.requestDeleteAccountInvocations.first)
			#expect(invocation?.userId == "9")
			#expect(invocation?.credential == APICredential(token: "tok", passwordHash: "hash"))
		}

		@Test func `marks deletion requested and wipes the local session on success`() async {
			let service = InMemoryAccountService(
				requestDeleteAccountResult: .success(AccountDeletionOutcome(message: nil)),
			)
			let (model, sessionStore) = AccountModelTests.makeModel(accountService: service)

			await model.requestDeletion()

			#expect(model.isDeletionRequested == true)
			#expect(sessionStore.isSignedIn == false)
			#expect(sessionStore.credential == nil)
		}

		@Test func `does not call requestDeleteAccount again once deletion has already been requested`() async {
			let service = InMemoryAccountService(
				requestDeleteAccountResult: .success(AccountDeletionOutcome(message: nil)),
			)
			let (model, _) = AccountModelTests.makeModel(accountService: service)
			await model.requestDeletion()

			await model.requestDeletion()

			#expect(service.requestDeleteAccountInvocations.count == 1)
		}

		@Test func `surfaces the server's message and stays signed in on a failed call`() async {
			let service = InMemoryAccountService(
				requestDeleteAccountResult: .failure(.server(message: "Please try again.")),
			)
			let (model, sessionStore) = AccountModelTests.makeModel(accountService: service)

			await model.requestDeletion()

			#expect(model.errorMessage == "Please try again.")
			#expect(model.isDeletionRequested == false)
			#expect(sessionStore.isSignedIn == true)
		}

		@Test func `surfaces a fallback message on a thrown connection error`() async {
			let service = InMemoryAccountService(requestDeleteAccountResult: .failure(.connection))
			let (model, _) = AccountModelTests.makeModel(accountService: service)

			await model.requestDeletion()

			#expect(model.errorMessage != nil)
			#expect(model.isDeletionRequested == false)
		}

		@Test func `clears a previous error message when retried successfully`() async {
			let service = InMemoryAccountService(requestDeleteAccountResult: .failure(.connection))
			let (model, _) = AccountModelTests.makeModel(accountService: service)
			await model.requestDeletion()
			service.requestDeleteAccountResult = .success(AccountDeletionOutcome(message: nil))

			await model.requestDeletion()

			#expect(model.errorMessage == nil)
			#expect(model.isDeletionRequested == true)
		}
	}

	struct Instrumentation {
		@Test func `tracks accountDeletionRequested on success`() async {
			let recorder = RecordingDestination()
			let service = InMemoryAccountService(
				requestDeleteAccountResult: .success(AccountDeletionOutcome(message: nil)),
			)
			let (model, _) = AccountModelTests.makeModel(
				accountService: service,
				observability: ObservabilityPipeline(destinations: [recorder]),
			)

			await model.requestDeletion()

			#expect(recorder.analytics.contains(AnalyticsPayload(name: "accountDeletionRequested", parameters: [:])))
		}

		@Test func `tracks accountDeletionRequestFailed on failure`() async {
			let recorder = RecordingDestination()
			let service = InMemoryAccountService(requestDeleteAccountResult: .failure(.connection))
			let (model, _) = AccountModelTests.makeModel(
				accountService: service,
				observability: ObservabilityPipeline(destinations: [recorder]),
			)

			await model.requestDeletion()

			#expect(recorder.analytics.contains(AnalyticsPayload(
				name: "accountDeletionRequestFailed",
				parameters: [:],
			)))
		}

		@Test func `requesting deletion leaves an interaction breadcrumb`() async {
			let recorder = RecordingDestination()
			let service = InMemoryAccountService(
				requestDeleteAccountResult: .success(AccountDeletionOutcome(message: nil)),
			)
			let (model, _) = AccountModelTests.makeModel(
				accountService: service,
				observability: ObservabilityPipeline(destinations: [recorder]),
			)

			await model.requestDeletion()

			#expect(recorder.breadcrumbs.contains(.interaction(description: "requestAccountDeletion")))
		}

		@Test func `reports the error on failure`() async {
			let recorder = RecordingDestination()
			let service = InMemoryAccountService(requestDeleteAccountResult: .failure(.connection))
			let (model, _) = AccountModelTests.makeModel(
				accountService: service,
				observability: ObservabilityPipeline(destinations: [recorder]),
			)

			await model.requestDeletion()

			let diagnostics = recorder.events.compactMap { event -> Diagnostic? in
				guard case .diagnostic(let diagnostic) = event else { return nil }
				return diagnostic
			}
			#expect(diagnostics.contains { $0.level == .error && $0.category == "Account" })
		}
	}
}
