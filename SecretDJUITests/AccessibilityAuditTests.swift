import XCTest

/// Runs `XCUIApplication.performAccessibilityAudit()` on every key consumer
/// screen (PLAN.md S8.2) — the automated half of the accessibility audit;
/// the VoiceOver walk and Dynamic Type layout checks are separate (this
/// file's sibling `DynamicTypeTests.swift`, and the manual VoiceOver pass
/// this stage's report lists). Every test launches through
/// ``UITestLaunching`` in UI-test mode, so nothing here ever touches the
/// real network.
///
/// Method names follow plain XCTest convention (`testFoo`, not Swift
/// Testing's raw-identifier style) deliberately: XCTest's runner discovers
/// tests by Objective-C selector, which can't represent a raw identifier
/// containing spaces.
///
/// `nonisolated` on the class: the project builds with
/// `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` (ios-architecture skill),
/// which would otherwise put this whole class on the main actor and
/// conflict with `XCTestCase`'s own nonisolated designated
/// initializers/lifecycle overrides — `nonisolated` opts this XCUITest
/// class (the swift-testing skill's one XCTest exception) back out,
/// matching plain XCTest's own isolation. ``UITestLaunching`` is
/// `nonisolated` for the same reason.
final nonisolated class AccessibilityAuditTests: XCTestCase {
	override func setUpWithError() throws {
		continueAfterFailure = false
	}

	// MARK: Signed out

	func testLoginScreen() throws {
		let app = UITestLaunching.launchSignedOut()
		XCTAssertTrue(app.staticTexts["Welcome Back"].waitForExistence(timeout: 10))

		try UITestLaunching.performAccessibilityAudit(on: app)
	}

	func testSignUpScreen() throws {
		let app = UITestLaunching.launchSignedOut()
		let signUp = app.buttons["SIGN ME UP"]
		XCTAssertTrue(signUp.waitForExistence(timeout: 10))
		signUp.tap()

		try UITestLaunching.performAccessibilityAudit(on: app)
	}

	func testForgottenPasswordScreen() throws {
		let app = UITestLaunching.launchSignedOut()
		let forgotPassword = app.buttons["Forgotten Your Password?"]
		XCTAssertTrue(forgotPassword.waitForExistence(timeout: 10))
		forgotPassword.tap()

		try UITestLaunching.performAccessibilityAudit(on: app)
	}

	// MARK: Signed in — tabs

	func testPlacesNearbyTab() throws {
		let app = UITestLaunching.launchSignedIn()
		XCTAssertTrue(UITestLaunching.element(labeled: "Fixture Venue", in: app).waitForExistence(timeout: 10))

		try UITestLaunching.performAccessibilityAudit(on: app)
	}

	func testActivityTab() throws {
		let app = UITestLaunching.launchSignedIn()
		let activityTab = UITestLaunching.tabBarButton(named: "Activity", in: app)
		XCTAssertTrue(activityTab.waitForExistence(timeout: 10))
		activityTab.tap()

		try UITestLaunching.performAccessibilityAudit(on: app)
	}

	func testProfileTab() throws {
		let app = UITestLaunching.launchSignedIn()
		let profileTab = UITestLaunching.tabBarButton(named: "Profile", in: app)
		XCTAssertTrue(profileTab.waitForExistence(timeout: 10))
		profileTab.tap()

		try UITestLaunching.performAccessibilityAudit(on: app)
	}

	// MARK: Signed in — pushed screens

	func testVenueScreen() throws {
		let app = UITestLaunching.launchSignedIn()
		let venueCell = UITestLaunching.element(labeled: "Fixture Venue", in: app)
		XCTAssertTrue(venueCell.waitForExistence(timeout: 10))
		venueCell.tap()

		XCTAssertTrue(app.buttons["Top Up"].waitForExistence(timeout: 10))
		try UITestLaunching.performAccessibilityAudit(on: app)
	}

	func testTuneInScreen() throws {
		let app = UITestLaunching.launchSignedIn()
		let songCell = UITestLaunching.element(labeled: "Fixture Song", in: app)
		XCTAssertTrue(songCell.waitForExistence(timeout: 10))
		songCell.tap()

		XCTAssertTrue(UITestLaunching.element(labeled: "Fixture Song", in: app).waitForExistence(timeout: 10))
		try UITestLaunching.performAccessibilityAudit(on: app)
	}

	func testTopUpsScreen() throws {
		let app = UITestLaunching.launchSignedIn()
		let venueCell = UITestLaunching.element(labeled: "Fixture Venue", in: app)
		XCTAssertTrue(venueCell.waitForExistence(timeout: 10))
		venueCell.tap()

		let topUp = app.buttons["Top Up"]
		XCTAssertTrue(topUp.waitForExistence(timeout: 10))
		topUp.tap()

		XCTAssertTrue(UITestLaunching.element(labeled: "Fixture Credits", in: app).waitForExistence(timeout: 10))
		try UITestLaunching.performAccessibilityAudit(on: app)
	}

	func testSettingsScreen() throws {
		let app = UITestLaunching.launchSignedIn()
		let profileTab = UITestLaunching.tabBarButton(named: "Profile", in: app)
		XCTAssertTrue(profileTab.waitForExistence(timeout: 10))
		profileTab.tap()

		let settings = app.buttons["Settings"]
		XCTAssertTrue(settings.waitForExistence(timeout: 10))
		settings.tap()

		try UITestLaunching.performAccessibilityAudit(on: app)
	}
}
