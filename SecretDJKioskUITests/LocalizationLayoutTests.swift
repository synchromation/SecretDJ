import XCTest

/// The automatable slice of PLAN.md S8.1's longest-language layout sweep —
/// mirrors the consumer target's own `LocalizationLayoutTests`
/// (`SecretDJUITests/LocalizationLayoutTests.swift`). Launches with
/// `-AppleLanguages (de)` and asserts each key kiosk screen's critical
/// controls still exist and are hittable under the real, translated German
/// strings, in the kiosk's only supported orientation. The visual pass
/// stays a human job; this only catches outright truncation/overlap.
///
/// `nonisolated` on the class: see `AccessibilityAuditTests`'s own doc
/// comment — the project's `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`
/// setting would otherwise conflict with `XCTestCase`'s nonisolated
/// designated initializers.
final nonisolated class LocalizationLayoutTests: XCTestCase {
	override func setUpWithError() throws {
		continueAfterFailure = false
	}

	/// Mirrors ``UITestLaunching/launchSignedOut()`` plus the
	/// `-AppleLanguages`/`-AppleLocale` pair that actually re-runs app
	/// launch under the German string catalog entries.
	private func launchSignedOutGerman() -> XCUIApplication {
		XCUIDevice.shared.orientation = .landscapeLeft
		let app = XCUIApplication()
		app.launchEnvironment["UITEST_MODE"] = "1"
		app.launchArguments += ["-AppleLanguages", "(de)", "-AppleLocale", "de_DE"]
		app.launch()
		return app
	}

	private func launchSignedInGerman() -> XCUIApplication {
		XCUIDevice.shared.orientation = .landscapeLeft
		let app = XCUIApplication()
		app.launchEnvironment["UITEST_MODE"] = "1"
		app.launchEnvironment["UITEST_SIGNED_IN"] = "1"
		app.launchArguments += ["-AppleLanguages", "(de)", "-AppleLocale", "de_DE"]
		app.launch()
		return app
	}

	/// "Venue Sign In" -> "Ortsanmeldung", "SIGN IN" -> "ANMELDEN" (German
	/// catalog values, `SecretDJKiosk/Localizable.xcstrings`).
	func testVenueSignInGermanLayout() {
		let app = launchSignedOutGerman()
		XCTAssertTrue(app.staticTexts["Ortsanmeldung"].waitForExistence(timeout: 10))

		let signIn = app.buttons["ANMELDEN"]
		XCTAssertTrue(signIn.waitForExistence(timeout: 10))
		XCTAssertTrue(signIn.isHittable)
	}

	/// "Search" -> "Suche" on the home/digest screen's search button.
	func testHomeDigestGermanLayout() {
		let app = launchSignedInGerman()
		XCTAssertTrue(UITestLaunching.element(labeled: "Fixture Song", in: app).waitForExistence(timeout: 15))

		let search = app.buttons["Suche"]
		XCTAssertTrue(search.waitForExistence(timeout: 10))
		XCTAssertTrue(search.isHittable)
	}
}
