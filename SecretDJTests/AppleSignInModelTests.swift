import Foundation
import Observability
import SecretDJAPI
import Testing

@testable import SecretDJ

@MainActor
enum AppleSignInModelTests {
	static let appleUserId = "00001234_a1b2c3d4"

	/// An explicit UTC calendar, so the day-of-year digest is reproducible.
	static let utcCalendar: Calendar = {
		var calendar = Calendar(identifier: .gregorian)
		calendar.timeZone = .gmt
		return calendar
	}()

	/// 2026-03-15T12:00:00Z — day 74 of a non-leap year.
	nonisolated static let fixedDate = Date(timeIntervalSince1970: 1_773_576_000)

	static var expectedDigest: String {
		AppleSignInAuthDigest.compute(appleUserId: appleUserId, date: fixedDate, calendar: utcCalendar)
	}

	static let cachedUserInfo = AppleUserInfo(
		appleUserId: appleUserId,
		firstName: "Tim",
		lastName: "Turbo",
		email: "tim@example.com",
	)

	static func makeSessionStore() -> SessionStore {
		SessionStore(snapshotStore: InMemorySessionSnapshotStore(), credentialStore: InMemoryCredentialStore())
	}

	static func makeAuthorizing(
		firstName: String? = nil,
		lastName: String? = nil,
		email: String? = nil,
	) -> InMemoryAppleAuthorizing {
		InMemoryAppleAuthorizing(result: .success(AppleAuthorizationResult(
			userId: appleUserId,
			firstName: firstName,
			lastName: lastName,
			email: email,
		)))
	}

	static func makeAuthService(
		created: Bool = false,
		issuedCredential: String? = "issued-credential",
		rotatedToken: String? = "tok",
	) -> InMemoryAuthenticationService {
		InMemoryAuthenticationService(appleSignInResult: .success(AppleAuthenticatedSession(
			personId: "41",
			screenName: "TurboTim",
			created: created,
			issuedCredential: issuedCredential,
			rotatedToken: rotatedToken,
		)))
	}

	static func makeAuthService(failing error: AuthenticationError) -> InMemoryAuthenticationService {
		InMemoryAuthenticationService(appleSignInResult: .failure(error))
	}

	static func makeModel(
		authorizing: InMemoryAppleAuthorizing = makeAuthorizing(),
		userInfoStore: InMemoryAppleUserInfoStore = InMemoryAppleUserInfoStore(),
		authService: InMemoryAuthenticationService = makeAuthService(),
		sessionStore: SessionStore = makeSessionStore(),
		observability: ObservabilityPipeline = .disabled,
	) -> AppleSignInModel {
		AppleSignInModel(
			appleAuthorizing: authorizing,
			appleUserInfoStore: userInfoStore,
			authService: authService,
			sessionStore: sessionStore,
			observability: observability,
			now: { fixedDate },
			calendar: utcCalendar,
		)
	}

	struct `Starting up` {
		@Test func `starts idle, with no error and no created account`() {
			let model = AppleSignInModelTests.makeModel()

			#expect(model.isSigningIn == false)
			#expect(model.errorMessage == nil)
			#expect(model.didCreateAccount == false)
		}
	}

	struct `Signing in` {
		@Test func `caches the name and email Apple supplies on a first authorization`() async {
			let store = InMemoryAppleUserInfoStore()
			let model = AppleSignInModelTests.makeModel(
				authorizing: AppleSignInModelTests.makeAuthorizing(
					firstName: "Tim",
					lastName: "Turbo",
					email: "tim@example.com",
				),
				userInfoStore: store,
			)

			await model.signInWithApple()

			#expect(store.saveInvocations == [AppleSignInModelTests.cachedUserInfo])
		}

		@Test func `sends the apple user id, the day-of-year digest, and Apple's name and email`() async {
			let authService = AppleSignInModelTests.makeAuthService()
			let model = AppleSignInModelTests.makeModel(
				authorizing: AppleSignInModelTests.makeAuthorizing(
					firstName: "Tim",
					lastName: "Turbo",
					email: "tim@example.com",
				),
				authService: authService,
			)

			await model.signInWithApple()

			#expect(authService.appleSignInInvocations == [AppleSignInInvocation(
				appleUserId: AppleSignInModelTests.appleUserId,
				auth: AppleSignInModelTests.expectedDigest,
				firstName: "Tim",
				lastName: "Turbo",
				email: "tim@example.com",
			)])
		}

		@Test func `signs the session in with the server-issued credential`() async {
			let sessionStore = AppleSignInModelTests.makeSessionStore()
			let model = AppleSignInModelTests.makeModel(sessionStore: sessionStore)

			await model.signInWithApple()

			#expect(sessionStore.isSignedIn == true)
			#expect(sessionStore.credential?.passwordHash == "issued-credential")
		}

		@Test func `leaves didCreateAccount false for an existing account`() async {
			let model = AppleSignInModelTests.makeModel(
				authService: AppleSignInModelTests.makeAuthService(created: false),
			)

			await model.signInWithApple()

			#expect(model.didCreateAccount == false)
		}

		@Test func `flags a brand-new account`() async {
			let model = AppleSignInModelTests.makeModel(
				authService: AppleSignInModelTests.makeAuthService(created: true),
			)

			await model.signInWithApple()

			#expect(model.didCreateAccount == true)
		}

		@Test func `stops signing in once the call completes`() async {
			let model = AppleSignInModelTests.makeModel()

			await model.signInWithApple()

			#expect(model.isSigningIn == false)
		}
	}

	struct `Recovering the cached name and email` {
		@Test func `sends the cached name and email when Apple supplies none`() async throws {
			let authService = AppleSignInModelTests.makeAuthService()
			let model = AppleSignInModelTests.makeModel(
				userInfoStore: InMemoryAppleUserInfoStore(userInfo: AppleSignInModelTests.cachedUserInfo),
				authService: authService,
			)

			await model.signInWithApple()

			let invocation = try #require(authService.appleSignInInvocations.first)
			#expect(invocation.firstName == "Tim")
			#expect(invocation.lastName == "Turbo")
			#expect(invocation.email == "tim@example.com")
		}

		@Test func `doesn't overwrite the cache when Apple supplies nothing`() async {
			let store = InMemoryAppleUserInfoStore(userInfo: AppleSignInModelTests.cachedUserInfo)
			let model = AppleSignInModelTests.makeModel(userInfoStore: store)

			await model.signInWithApple()

			#expect(store.saveInvocations.isEmpty)
		}

		@Test func `sends no name or email when neither Apple nor the cache has any`() async throws {
			let authService = AppleSignInModelTests.makeAuthService()
			let model = AppleSignInModelTests.makeModel(authService: authService)

			await model.signInWithApple()

			let invocation = try #require(authService.appleSignInInvocations.first)
			#expect(invocation.firstName == nil)
			#expect(invocation.lastName == nil)
			#expect(invocation.email == nil)
		}
	}

	struct Failing {
		@Test func `a cancelled authorization never reaches the server`() async {
			let sessionStore = AppleSignInModelTests.makeSessionStore()
			let authService = AppleSignInModelTests.makeAuthService()
			let model = AppleSignInModelTests.makeModel(
				authorizing: InMemoryAppleAuthorizing(result: .failure(.cancelled)),
				authService: authService,
				sessionStore: sessionStore,
			)

			await model.signInWithApple()

			#expect(authService.appleSignInInvocations.isEmpty)
			#expect(sessionStore.isSignedIn == false)
		}

		@Test func `a cancelled authorization shows no message`() async {
			let model = AppleSignInModelTests.makeModel(
				authorizing: InMemoryAppleAuthorizing(result: .failure(.cancelled)),
			)

			await model.signInWithApple()

			#expect(model.errorMessage == nil)
			#expect(model.isSigningIn == false)
		}

		@Test func `a failed authorization never reaches the server`() async {
			let authService = AppleSignInModelTests.makeAuthService()
			let model = AppleSignInModelTests.makeModel(
				authorizing: InMemoryAppleAuthorizing(result: .failure(.failed)),
				authService: authService,
			)

			await model.signInWithApple()

			#expect(authService.appleSignInInvocations.isEmpty)
			#expect(model.errorMessage != nil)
		}

		@Test func `distinguishes a failed authorization from a connection failure`() async {
			let authorizationFailure = AppleSignInModelTests.makeModel(
				authorizing: InMemoryAppleAuthorizing(result: .failure(.failed)),
			)
			let connectionFailure = AppleSignInModelTests.makeModel(
				authService: AppleSignInModelTests.makeAuthService(failing: .connection),
			)

			await authorizationFailure.signInWithApple()
			await connectionFailure.signInWithApple()

			#expect(authorizationFailure.errorMessage != connectionFailure.errorMessage)
		}

		@Test func `surfaces the server's message`() async {
			let sessionStore = AppleSignInModelTests.makeSessionStore()
			let model = AppleSignInModelTests.makeModel(
				authService: AppleSignInModelTests.makeAuthService(failing: .server(message: "Some message")),
				sessionStore: sessionStore,
			)

			await model.signInWithApple()

			#expect(model.errorMessage == "Some message")
			#expect(sessionStore.isSignedIn == false)
			#expect(model.didCreateAccount == false)
		}

		@Test func `surfaces a fallback message on a connection failure`() async {
			let model = AppleSignInModelTests.makeModel(
				authService: AppleSignInModelTests.makeAuthService(failing: .connection),
			)

			await model.signInWithApple()

			#expect(model.errorMessage != nil)
		}

		@Test func `stays signed out when the response carries no rotated token`() async {
			let sessionStore = AppleSignInModelTests.makeSessionStore()
			let model = AppleSignInModelTests.makeModel(
				authService: AppleSignInModelTests.makeAuthService(rotatedToken: nil),
				sessionStore: sessionStore,
			)

			await model.signInWithApple()

			#expect(sessionStore.isSignedIn == false)
			#expect(model.errorMessage != nil)
		}

		@Test func `stays signed out when the response carries no issued credential`() async {
			let sessionStore = AppleSignInModelTests.makeSessionStore()
			let model = AppleSignInModelTests.makeModel(
				authService: AppleSignInModelTests.makeAuthService(created: true, issuedCredential: nil),
				sessionStore: sessionStore,
			)

			await model.signInWithApple()

			#expect(sessionStore.isSignedIn == false)
			#expect(model.errorMessage != nil)
			#expect(model.didCreateAccount == false)
		}
	}

	struct Instrumentation {
		@Test func `signing in leaves an interaction breadcrumb`() async {
			let recorder = RecordingDestination()
			let model = AppleSignInModelTests.makeModel(
				observability: ObservabilityPipeline(destinations: [recorder]),
			)

			await model.signInWithApple()

			#expect(recorder.breadcrumbs.contains(.interaction(description: "signInWithApple")))
		}

		@Test func `a failed sign-in still leaves an interaction breadcrumb`() async {
			let recorder = RecordingDestination()
			let model = AppleSignInModelTests.makeModel(
				authorizing: InMemoryAppleAuthorizing(result: .failure(.failed)),
				observability: ObservabilityPipeline(destinations: [recorder]),
			)

			await model.signInWithApple()

			#expect(recorder.breadcrumbs.contains(.interaction(description: "signInWithApple")))
		}

		@Test func `a brand-new account tracks the appleAccountCreated analytics event`() async {
			let recorder = RecordingDestination()
			let model = AppleSignInModelTests.makeModel(
				authService: AppleSignInModelTests.makeAuthService(created: true),
				observability: ObservabilityPipeline(destinations: [recorder]),
			)

			await model.signInWithApple()

			#expect(recorder.analytics == [AnalyticsPayload(name: "appleAccountCreated", parameters: [:])])
		}

		@Test func `a failed sign-in is reported, without logging the apple user id, name, or email`() async {
			let recorder = RecordingDestination()
			let model = AppleSignInModelTests.makeModel(
				authorizing: AppleSignInModelTests.makeAuthorizing(
					firstName: "Tim",
					lastName: "SensitiveSurname",
					email: "tim@example.com",
				),
				authService: AppleSignInModelTests.makeAuthService(failing: .server(message: "Some message")),
				observability: ObservabilityPipeline(destinations: [recorder]),
			)

			await model.signInWithApple()

			let diagnostics = recorder.diagnosticMessages
			#expect(diagnostics.isEmpty == false)
			#expect(diagnostics.contains { $0.contains(AppleSignInModelTests.appleUserId) } == false)
			#expect(diagnostics.contains { $0.contains("SensitiveSurname") } == false)
			#expect(diagnostics.contains { $0.contains("tim@example.com") } == false)
		}

		@Test func `a cancelled authorization is not reported`() async {
			let recorder = RecordingDestination()
			let model = AppleSignInModelTests.makeModel(
				authorizing: InMemoryAppleAuthorizing(result: .failure(.cancelled)),
				observability: ObservabilityPipeline(destinations: [recorder]),
			)

			await model.signInWithApple()

			#expect(recorder.diagnosticMessages.isEmpty)
		}
	}
}

extension RecordingDestination {
	fileprivate var diagnosticMessages: [String] {
		events.compactMap { event in
			guard case .diagnostic(let diagnostic) = event else {
				return nil
			}

			return diagnostic.message
		}
	}
}
