import Observability
import Testing

@testable import SecretDJ

@MainActor
enum ForgottenPasswordModelTests {
	struct `Starting up` {
		@Test func `cannot submit with empty input`() {
			let model = ForgottenPasswordModel(authService: InMemoryAuthenticationService())

			#expect(model.canSubmit == false)
		}

		@Test func `cannot submit with only whitespace`() {
			let model = ForgottenPasswordModel(authService: InMemoryAuthenticationService())

			model.updateInput("   ")

			#expect(model.canSubmit == false)
		}

		@Test func `can submit once there's input`() {
			let model = ForgottenPasswordModel(authService: InMemoryAuthenticationService())

			model.updateInput("TurboTim")

			#expect(model.canSubmit == true)
		}
	}

	struct Submitting {
		@Test func `treats an input containing an at sign as an email`() async {
			let authService = InMemoryAuthenticationService(
				resetPasswordResult: .success(PasswordResetOutcome(succeeded: true, message: "Check your email.")),
			)
			let model = ForgottenPasswordModel(authService: authService)
			model.updateInput("tim@example.com")

			await model.submit()

			#expect(authService.resetPasswordEmailInvocations == ["tim@example.com"])
			#expect(authService.resetPasswordScreenNameInvocations.isEmpty)
		}

		@Test func `treats an input without an at sign as a screen name`() async {
			let authService = InMemoryAuthenticationService(
				resetPasswordResult: .success(PasswordResetOutcome(succeeded: true, message: "Check your email.")),
			)
			let model = ForgottenPasswordModel(authService: authService)
			model.updateInput("TurboTim")

			await model.submit()

			#expect(authService.resetPasswordScreenNameInvocations == ["TurboTim"])
			#expect(authService.resetPasswordEmailInvocations.isEmpty)
		}

		@Test func `does nothing with empty input`() async {
			let authService = InMemoryAuthenticationService()
			let model = ForgottenPasswordModel(authService: authService)

			await model.submit()

			#expect(authService.resetPasswordScreenNameInvocations.isEmpty)
			#expect(authService.resetPasswordEmailInvocations.isEmpty)
		}

		@Test func `shows the server's confirmation message on success`() async {
			let authService = InMemoryAuthenticationService(
				resetPasswordResult: .success(PasswordResetOutcome(
					succeeded: true,
					message: "Check your email, TurboTim.",
				)),
			)
			let model = ForgottenPasswordModel(authService: authService)
			model.updateInput("TurboTim")

			await model.submit()

			#expect(model.resultMessage == "Check your email, TurboTim.")
			#expect(model.didSucceed == true)
		}

		@Test func `falls back to a generic confirmation when the server sends no message`() async {
			let authService = InMemoryAuthenticationService(
				resetPasswordResult: .success(PasswordResetOutcome(succeeded: true, message: nil)),
			)
			let model = ForgottenPasswordModel(authService: authService)
			model.updateInput("TurboTim")

			await model.submit()

			#expect(model.resultMessage != nil)
			#expect(model.didSucceed == true)
		}

		@Test func `shows the server's error message when the server rejects the request`() async {
			let authService = InMemoryAuthenticationService(
				resetPasswordResult: .success(PasswordResetOutcome(
					succeeded: false,
					message: "Sorry, you must enter either the username or email associated with your account.",
				)),
			)
			let model = ForgottenPasswordModel(authService: authService)
			model.updateInput("TurboTim")

			await model.submit()

			#expect(model
				.resultMessage == "Sorry, you must enter either the username or email associated with your account.")
			#expect(model.didSucceed == false)
		}

		@Test func `shows a fallback message on a connection failure`() async {
			let authService = InMemoryAuthenticationService(resetPasswordResult: .failure(.connection))
			let model = ForgottenPasswordModel(authService: authService)
			model.updateInput("TurboTim")

			await model.submit()

			#expect(model.resultMessage != nil)
			#expect(model.didSucceed == false)
		}
	}

	struct Instrumentation {
		@Test func `submitting leaves an interaction breadcrumb`() async {
			let recorder = RecordingDestination()
			let authService = InMemoryAuthenticationService(
				resetPasswordResult: .success(PasswordResetOutcome(succeeded: true, message: "Check your email.")),
			)
			let model = ForgottenPasswordModel(
				authService: authService,
				observability: ObservabilityPipeline(destinations: [recorder]),
			)
			model.updateInput("TurboTim")

			await model.submit()

			#expect(recorder.breadcrumbs.contains(.interaction(description: "resetPassword")))
		}

		@Test func `a connection failure is reported without logging the input`() async {
			let recorder = RecordingDestination()
			let authService = InMemoryAuthenticationService(resetPasswordResult: .failure(.connection))
			let model = ForgottenPasswordModel(
				authService: authService,
				observability: ObservabilityPipeline(destinations: [recorder]),
			)
			model.updateInput("sensitive-screen-name")

			await model.submit()

			let diagnostics = recorder.events.compactMap { event -> String? in
				guard case .diagnostic(let diagnostic) = event else { return nil }
				return diagnostic.message
			}
			#expect(diagnostics.contains { $0.contains("sensitive-screen-name") } == false)
		}
	}
}
