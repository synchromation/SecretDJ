import Foundation

/// Gates the in-process dependency substitution ``SecretDJKioskApp`` makes
/// when launched by the `SecretDJKioskUITests` target (PLAN.md S8.2) —
/// mirrors the consumer app's own `UITestMode`
/// (`SecretDJ/Support/UITesting/UITestMode.swift`). This is the *only* place
/// the kiosk app decides whether it's running under UI-test automation;
/// nothing downstream ever re-checks the environment.
enum UITestMode {
	/// Set by every `SecretDJKioskUITests` test via `launchEnvironment`
	/// before `XCUIApplication.launch()`. When `true`,
	/// ``UITestDependencies`` replaces every network- or hardware-backed
	/// dependency the composition root builds with a deterministic,
	/// in-memory fixture — no test ever touches the real network.
	static var isActive: Bool {
		ProcessInfo.processInfo.environment["UITEST_MODE"] == "1"
	}

	/// Whether the fixture session should start already checked into a
	/// fixture venue (`UITEST_SIGNED_IN=1`, showing the skin gate then the
	/// kiosk home) or signed out (the default, showing venue sign-in).
	/// Ignored when ``isActive`` is `false`.
	static var isSignedIn: Bool {
		ProcessInfo.processInfo.environment["UITEST_SIGNED_IN"] == "1"
	}
}
