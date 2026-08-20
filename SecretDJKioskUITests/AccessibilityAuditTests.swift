import XCTest

/// Runs `XCUIApplication.performAccessibilityAudit()` on every key kiosk
/// screen (PLAN.md S8.2) — mirrors the consumer target's own
/// `AccessibilityAuditTests` (`SecretDJUITests/AccessibilityAuditTests.swift`).
/// Every test launches through ``UITestLaunching`` in UI-test mode and
/// forces landscape, so nothing here ever touches the real network and
/// every screen audits in the kiosk's only supported orientation.
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

	func testVenueSignInScreen() throws {
		let app = UITestLaunching.launchSignedOut()
		XCTAssertTrue(app.staticTexts["Venue Sign In"].waitForExistence(timeout: 10))

		try UITestLaunching.performAccessibilityAudit(on: app)
	}

	func testHomeDigestScreen() throws {
		let app = UITestLaunching.launchSignedIn()
		XCTAssertTrue(UITestLaunching.element(labeled: "Fixture Song", in: app).waitForExistence(timeout: 15))

		try UITestLaunching.performAccessibilityAudit(on: app)
	}

	func testSearchScreen() throws {
		let app = UITestLaunching.launchSignedIn()
		let search = app.buttons["Search"]
		XCTAssertTrue(search.waitForExistence(timeout: 15))
		search.tap()

		try UITestLaunching.performAccessibilityAudit(on: app)
	}

	func testTuneInScreen() throws {
		let app = UITestLaunching.launchSignedIn()
		let songCell = UITestLaunching.waitForTappableElement(labeled: "Fixture Song", in: app, timeout: 15)
		songCell.tap()

		XCTAssertTrue(UITestLaunching.element(labeled: "Fixture Song", in: app).waitForExistence(timeout: 10))
		try UITestLaunching.performAccessibilityAudit(on: app)
	}
}
