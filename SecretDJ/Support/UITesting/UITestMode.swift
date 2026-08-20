import Foundation

/// Gates the in-process dependency substitution ``SecretDJApp`` makes when
/// launched by the `SecretDJUITests` target (PLAN.md S8.2). This is the
/// *only* place the consumer app decides whether it's running under UI-test
/// automation — `SecretDJApp.init()` reads ``isActive``/``isSignedIn`` once,
/// at composition time, and hands the result down as ordinary dependency
/// values; nothing downstream ever re-checks the environment.
///
/// Never active outside a UI test run: both flags default to `false`, and
/// only `XCUIApplication.launchEnvironment` (set exclusively by
/// `SecretDJUITests`) can turn them on.
enum UITestMode {
	/// Set by every `SecretDJUITests` test via `launchEnvironment` before
	/// `XCUIApplication.launch()`. When `true`, ``UITestDependencies``
	/// replaces every network- or hardware-backed dependency the
	/// composition root builds with a deterministic, in-memory fixture —
	/// no test ever touches the real network, StoreKit, or Core Location.
	static var isActive: Bool {
		ProcessInfo.processInfo.environment["UITEST_MODE"] == "1"
	}

	/// Whether the fixture session should start already signed in
	/// (`UITEST_SIGNED_IN=1`, showing the three-tab shell) or signed out
	/// (the default, showing the login flow). Ignored when ``isActive`` is
	/// `false`.
	static var isSignedIn: Bool {
		ProcessInfo.processInfo.environment["UITEST_SIGNED_IN"] == "1"
	}
}
