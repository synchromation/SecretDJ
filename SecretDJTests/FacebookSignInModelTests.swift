import Foundation
import Observability
import SecretDJAPI
import SecretDJDomain
import Testing

@testable import SecretDJ

@MainActor
enum FacebookSignInModelTests {
	static let facebookUserId = "10154089931213890"

	static let utcCalendar: Calendar = {
		var calendar = Calendar(identifier: .gregorian)
		calendar.timeZone = .gmt
		return calendar
	}()

	/// 2026-03-15T12:00:00Z — day 74 of a non-leap year.
	nonisolated static let fixedDate = Date(timeIntervalSince1970: 1_773_576_000)

	static var expectedDigest: String {
		FacebookSignInAuthDigest.compute(facebookUserId: facebookUserId, date: fixedDate, calendar: utcCalendar)
	}

	static func makeSessionStore() -> SessionStore {
		SessionStore(snapshotStore: InMemorySessionSnapshotStore(), credentialStore: InMemoryCredentialStore())
	}

	static func makeFacebookAuthorizing(
		gender: Gender? = nil,
		firstName: String? = nil,
		lastName: String? = nil,
		email: String? = nil,
	) -> InMemoryFacebookAuthorizing {
		InMemoryFacebookAuthorizing(result: .success(FacebookAuthorizationResult(
			facebookUserId: facebookUserId,
			accessToken: "fb-token",
			gender: gender,
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
		InMemoryAuthenticationService(facebookSignInResult: .success(SocialAuthenticatedSession(
			personId: "41",
			screenName: "TurboTim",
			created: created,
			issuedCredential: issuedCredential,
			rotatedToken: rotatedToken,
		)))
	}

	static func makeAuthService(failing error: AuthenticationError) -> InMemoryAuthenticationService {
		InMemoryAuthenticationService(facebookSignInResult: .failure(error))
	}

	static func makeModel(
		tracking: InMemoryTrackingAuthorizing = InMemoryTrackingAuthorizing(status: .authorized),
		facebookAuthorizing: InMemoryFacebookAuthorizing = makeFacebookAuthorizing(),
		authService: InMemoryAuthenticationService = makeAuthService(),
		sessionStore: SessionStore = makeSessionStore(),
		observability: ObservabilityPipeline = .disabled,
	) -> FacebookSignInModel {
		FacebookSignInModel(
			trackingAuthorizing: tracking,
			facebookAuthorizing: facebookAuthorizing,
			authService: authService,
			sessionStore: sessionStore,
			observability: observability,
			now: { fixedDate },
			calendar: utcCalendar,
		)
	}

	struct `Starting up` {
		@Test func `starts idle, with no error and no created account`() {
			let model = FacebookSignInModelTests.makeModel()

			#expect(model.isSigningIn == false)
			#expect(model.errorMessage == nil)
			#expect(model.didCreateAccount == false)
		}

		@Test func `reads the tracking status at construction`() {
			let model = FacebookSignInModelTests.makeModel(tracking: InMemoryTrackingAuthorizing(status: .denied))

			#expect(model.trackingStatus == .denied)
		}
	}

	struct `Gating on tracking authorization` {
		@Test func `canSignIn is false once tracking has been denied`() {
			let model = FacebookSignInModelTests.makeModel(tracking: InMemoryTrackingAuthorizing(status: .denied))

			#expect(model.canSignIn == false)
		}

		@Test func `canSignIn is false when tracking is restricted`() {
			let model = FacebookSignInModelTests.makeModel(tracking: InMemoryTrackingAuthorizing(status: .restricted))

			#expect(model.canSignIn == false)
		}

		@Test func `canSignIn is true when not yet determined`() {
			let model = FacebookSignInModelTests
				.makeModel(tracking: InMemoryTrackingAuthorizing(status: .notDetermined))

			#expect(model.canSignIn == true)
		}

		@Test func `a denied session never reaches Facebook authorization`() async {
			let facebookAuthorizing = FacebookSignInModelTests.makeFacebookAuthorizing()
			let model = FacebookSignInModelTests.makeModel(
				tracking: InMemoryTrackingAuthorizing(status: .denied),
				facebookAuthorizing: facebookAuthorizing,
			)

			await model.signInWithFacebook()

			#expect(facebookAuthorizing.requestCount == 0)
		}

		@Test func `requests tracking authorization when not yet determined, then proceeds once authorized`() async {
			let tracking = InMemoryTrackingAuthorizing(status: .notDetermined, requestedStatus: .authorized)
			let facebookAuthorizing = FacebookSignInModelTests.makeFacebookAuthorizing()
			let model = FacebookSignInModelTests.makeModel(tracking: tracking, facebookAuthorizing: facebookAuthorizing)

			await model.signInWithFacebook()

			#expect(tracking.requestCount == 1)
			#expect(facebookAuthorizing.requestCount == 1)
			#expect(model.trackingStatus == .authorized)
		}

		@Test func `stops without a message when the user rejects tracking mid-flow`() async {
			let tracking = InMemoryTrackingAuthorizing(status: .notDetermined, requestedStatus: .denied)
			let facebookAuthorizing = FacebookSignInModelTests.makeFacebookAuthorizing()
			let model = FacebookSignInModelTests.makeModel(tracking: tracking, facebookAuthorizing: facebookAuthorizing)

			await model.signInWithFacebook()

			#expect(facebookAuthorizing.requestCount == 0)
			#expect(model.errorMessage == nil)
			#expect(model.isSigningIn == false)
			#expect(model.trackingStatus == .denied)
		}
	}

	struct `Signing in` {
		@Test func `sends the facebook user id, access token, and the day-of-year digest`() async {
			let authService = FacebookSignInModelTests.makeAuthService()
			let model = FacebookSignInModelTests.makeModel(authService: authService)

			await model.signInWithFacebook()

			#expect(authService.facebookSignInInvocations == [FacebookSignInInvocation(
				facebookUserId: FacebookSignInModelTests.facebookUserId,
				accessToken: "fb-token",
				auth: FacebookSignInModelTests.expectedDigest,
				gender: nil,
				firstName: nil,
				lastName: nil,
				email: nil,
			)])
		}

		@Test func `sends every profile field the Facebook authorization carried`() async {
			let authService = FacebookSignInModelTests.makeAuthService()
			let model = FacebookSignInModelTests.makeModel(
				facebookAuthorizing: FacebookSignInModelTests.makeFacebookAuthorizing(
					gender: .female,
					firstName: "Tim",
					lastName: "Turbo",
					email: "tim@example.com",
				),
				authService: authService,
			)

			await model.signInWithFacebook()

			let invocation = try? #require(authService.facebookSignInInvocations.first)
			#expect(invocation?.gender == .female)
			#expect(invocation?.firstName == "Tim")
			#expect(invocation?.lastName == "Turbo")
			#expect(invocation?.email == "tim@example.com")
		}

		@Test func `signs the session in with the server-issued credential`() async {
			let sessionStore = FacebookSignInModelTests.makeSessionStore()
			let model = FacebookSignInModelTests.makeModel(sessionStore: sessionStore)

			await model.signInWithFacebook()

			#expect(sessionStore.isSignedIn == true)
			#expect(sessionStore.credential?.passwordHash == "issued-credential")
		}

		@Test func `leaves didCreateAccount false for an existing account`() async {
			let model = FacebookSignInModelTests.makeModel(
				authService: FacebookSignInModelTests.makeAuthService(created: false),
			)

			await model.signInWithFacebook()

			#expect(model.didCreateAccount == false)
		}

		@Test func `flags a brand-new account`() async {
			let model = FacebookSignInModelTests.makeModel(
				authService: FacebookSignInModelTests.makeAuthService(created: true),
			)

			await model.signInWithFacebook()

			#expect(model.didCreateAccount == true)
		}

		@Test func `stops signing in once the call completes`() async {
			let model = FacebookSignInModelTests.makeModel()

			await model.signInWithFacebook()

			#expect(model.isSigningIn == false)
		}
	}

	struct Failing {
		@Test func `a cancelled authorization never reaches the server`() async {
			let sessionStore = FacebookSignInModelTests.makeSessionStore()
			let authService = FacebookSignInModelTests.makeAuthService()
			let model = FacebookSignInModelTests.makeModel(
				facebookAuthorizing: InMemoryFacebookAuthorizing(result: .failure(.cancelled)),
				authService: authService,
				sessionStore: sessionStore,
			)

			await model.signInWithFacebook()

			#expect(authService.facebookSignInInvocations.isEmpty)
			#expect(sessionStore.isSignedIn == false)
		}

		@Test func `a cancelled authorization shows no message`() async {
			let model = FacebookSignInModelTests.makeModel(
				facebookAuthorizing: InMemoryFacebookAuthorizing(result: .failure(.cancelled)),
			)

			await model.signInWithFacebook()

			#expect(model.errorMessage == nil)
			#expect(model.isSigningIn == false)
		}

		@Test func `a failed authorization never reaches the server`() async {
			let authService = FacebookSignInModelTests.makeAuthService()
			let model = FacebookSignInModelTests.makeModel(
				facebookAuthorizing: InMemoryFacebookAuthorizing(result: .failure(.failed)),
				authService: authService,
			)

			await model.signInWithFacebook()

			#expect(authService.facebookSignInInvocations.isEmpty)
			#expect(model.errorMessage != nil)
		}

		@Test func `surfaces the server's message`() async {
			let sessionStore = FacebookSignInModelTests.makeSessionStore()
			let model = FacebookSignInModelTests.makeModel(
				authService: FacebookSignInModelTests.makeAuthService(failing: .server(message: "Some message")),
				sessionStore: sessionStore,
			)

			await model.signInWithFacebook()

			#expect(model.errorMessage == "Some message")
			#expect(sessionStore.isSignedIn == false)
			#expect(model.didCreateAccount == false)
		}

		@Test func `surfaces a fallback message on a connection failure`() async {
			let model = FacebookSignInModelTests.makeModel(
				authService: FacebookSignInModelTests.makeAuthService(failing: .connection),
			)

			await model.signInWithFacebook()

			#expect(model.errorMessage != nil)
		}

		@Test func `stays signed out when the response carries no rotated token`() async {
			let sessionStore = FacebookSignInModelTests.makeSessionStore()
			let model = FacebookSignInModelTests.makeModel(
				authService: FacebookSignInModelTests.makeAuthService(rotatedToken: nil),
				sessionStore: sessionStore,
			)

			await model.signInWithFacebook()

			#expect(sessionStore.isSignedIn == false)
			#expect(model.errorMessage != nil)
		}
	}

	struct Instrumentation {
		@Test func `signing in leaves an interaction breadcrumb`() async {
			let recorder = RecordingDestination()
			let model = FacebookSignInModelTests.makeModel(
				observability: ObservabilityPipeline(destinations: [recorder]),
			)

			await model.signInWithFacebook()

			#expect(recorder.breadcrumbs.contains(.interaction(description: "signInWithFacebook")))
		}

		@Test func `a brand-new account tracks the facebookAccountCreated analytics event`() async {
			let recorder = RecordingDestination()
			let model = FacebookSignInModelTests.makeModel(
				authService: FacebookSignInModelTests.makeAuthService(created: true),
				observability: ObservabilityPipeline(destinations: [recorder]),
			)

			await model.signInWithFacebook()

			#expect(recorder.analytics == [AnalyticsPayload(name: "facebookAccountCreated", parameters: [:])])
		}

		@Test func `a failed sign-in is reported, without logging the facebook user id, name, or email`() async {
			let recorder = RecordingDestination()
			let model = FacebookSignInModelTests.makeModel(
				facebookAuthorizing: FacebookSignInModelTests.makeFacebookAuthorizing(
					firstName: "Tim",
					lastName: "SensitiveSurname",
					email: "tim@example.com",
				),
				authService: FacebookSignInModelTests.makeAuthService(failing: .server(message: "Some message")),
				observability: ObservabilityPipeline(destinations: [recorder]),
			)

			await model.signInWithFacebook()

			let diagnostics = recorder.events.compactMap { event -> String? in
				guard case .diagnostic(let diagnostic) = event else { return nil }
				return diagnostic.message
			}
			#expect(diagnostics.isEmpty == false)
			#expect(diagnostics.contains { $0.contains(FacebookSignInModelTests.facebookUserId) } == false)
			#expect(diagnostics.contains { $0.contains("SensitiveSurname") } == false)
			#expect(diagnostics.contains { $0.contains("tim@example.com") } == false)
		}

		@Test func `a cancelled authorization is not reported`() async {
			let recorder = RecordingDestination()
			let model = FacebookSignInModelTests.makeModel(
				facebookAuthorizing: InMemoryFacebookAuthorizing(result: .failure(.cancelled)),
				observability: ObservabilityPipeline(destinations: [recorder]),
			)

			await model.signInWithFacebook()

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
