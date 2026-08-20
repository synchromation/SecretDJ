import XCTest

/// The automatable slice of PLAN.md S8.1's longest-language layout sweep:
/// launches with `-AppleLanguages (de)` (German runs ~30% longer per the
/// localization skill's `language-adaptations.md`, the tightest length risk
/// alongside Dutch) and asserts each key screen's critical controls still
/// exist and are hittable under the real, translated German strings — not
/// just present, the same bar `DynamicTypeTests` holds for accessibility5.
/// The visual pass (does it *look* right, not just respond to a tap) stays
/// a human job; this only catches outright truncation/overlap that pushes a
/// control off-screen or collapses its hit target.
///
/// `nonisolated` on the class: see `AccessibilityAuditTests`'s own doc
/// comment — the project's `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`
/// setting would otherwise conflict with `XCTestCase`'s nonisolated
/// designated initializers.
final nonisolated class LocalizationLayoutTests: XCTestCase {
	override func setUpWithError() throws {
		continueAfterFailure = false
	}

	/// Launches signed out, forcing German — mirrors ``UITestLaunching/launchSignedOut()``
	/// plus the `-AppleLanguages`/`-AppleLocale` pair that actually re-runs
	/// app launch under the German string catalog entries (UI-test mode
	/// alone doesn't change device language).
	private func launchSignedOutGerman() -> XCUIApplication {
		let app = XCUIApplication()
		app.launchEnvironment["UITEST_MODE"] = "1"
		app.launchArguments += ["-AppleLanguages", "(de)", "-AppleLocale", "de_DE"]
		app.launch()
		return app
	}

	private func launchSignedInGerman() -> XCUIApplication {
		let app = XCUIApplication()
		app.launchEnvironment["UITEST_MODE"] = "1"
		app.launchEnvironment["UITEST_SIGNED_IN"] = "1"
		app.launchArguments += ["-AppleLanguages", "(de)", "-AppleLocale", "de_DE"]
		app.launch()
		return app
	}

	// MARK: Signed out — login/sign-up

	/// "SIGN IN" -> "ANMELDEN", "SIGN ME UP" -> "ICH MELDE MICH AN",
	/// "Forgotten Your Password?" -> "Passwort vergessen?" (German catalog
	/// values, `SecretDJ/Localizable.xcstrings`) — the longest of the three
	/// is the sign-up button, an 18-character all-caps phrase versus the
	/// 8-character English source.
	func testLoginScreenGermanLayout() {
		let app = launchSignedOutGerman()
		XCTAssertTrue(app.staticTexts["Willkommen zurück"].waitForExistence(timeout: 10))

		let signIn = app.buttons["ANMELDEN"]
		XCTAssertTrue(signIn.waitForExistence(timeout: 10))
		XCTAssertTrue(signIn.isHittable)

		let signUp = app.buttons["ICH MELDE MICH AN"]
		XCTAssertTrue(signUp.waitForExistence(timeout: 10))
		XCTAssertTrue(signUp.isHittable)

		let forgotPassword = app.buttons["Passwort vergessen?"]
		XCTAssertTrue(forgotPassword.waitForExistence(timeout: 10))
		XCTAssertTrue(forgotPassword.isHittable)
	}

	// MARK: Signed in — tab bar

	/// "Places Nearby" -> "Orte in der Nähe", "Activity" -> "Aktivität",
	/// "Profile" -> "Profil" (German catalog values) — the tab bar reflows
	/// at accessibility text sizes (`UITestLaunching`'s own doc comment);
	/// this confirms it also survives German's longer tab titles at the
	/// default text size.
	func testSignedInTabBarGermanLayout() {
		let app = launchSignedInGerman()
		XCTAssertTrue(UITestLaunching.element(labeled: "Fixture Venue", in: app).waitForExistence(timeout: 10))

		let placesNearby = UITestLaunching.tabBarButton(named: "Orte in der Nähe", in: app)
		XCTAssertTrue(placesNearby.waitForExistence(timeout: 10))
		XCTAssertTrue(placesNearby.isHittable)

		let activity = UITestLaunching.tabBarButton(named: "Aktivität", in: app)
		XCTAssertTrue(activity.waitForExistence(timeout: 10))
		XCTAssertTrue(activity.isHittable)

		let profile = UITestLaunching.tabBarButton(named: "Profil", in: app)
		XCTAssertTrue(profile.waitForExistence(timeout: 10))
		XCTAssertTrue(profile.isHittable)
	}

	// MARK: Signed in — venue screen

	/// "Top Up" -> "Aufladen" on the venue screen's credits button.
	func testVenueScreenGermanLayout() {
		let app = launchSignedInGerman()
		let venueCell = UITestLaunching.element(labeled: "Fixture Venue", in: app)
		XCTAssertTrue(venueCell.waitForExistence(timeout: 10))
		venueCell.tap()

		let topUp = app.buttons["Aufladen"]
		XCTAssertTrue(topUp.waitForExistence(timeout: 10))
		XCTAssertTrue(topUp.isHittable)
	}
}
