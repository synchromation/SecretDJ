import XCTest

/// Launches at accessibility5 (`-UIPreferredContentSizeCategoryName`, the
/// largest Dynamic Type step) and asserts key screens stay usable — every
/// element a person needs to act on still exists and is hittable, not just
/// present (PLAN.md S8.2: "Dynamic Type through accessibility5"). The
/// automated accessibility audit (`AccessibilityAuditTests.swift`) already
/// covers labelling/contrast/hit-target rules at the default size; this
/// file is the size-specific layout check the audit API doesn't reach.
///
/// `nonisolated` on the class: see `AccessibilityAuditTests`'s own doc
/// comment — the project's `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`
/// setting would otherwise conflict with `XCTestCase`'s nonisolated
/// designated initializers.
final nonisolated class DynamicTypeTests: XCTestCase {
	override func setUpWithError() throws {
		continueAfterFailure = false
	}

	func testLoginScreenUsableAtAccessibility5() {
		let app = XCUIApplication()
		app.launchEnvironment["UITEST_MODE"] = "1"
		app.launchArguments += [
			"-UIPreferredContentSizeCategoryName", UITestLaunching.accessibility5ContentSizeCategory,
		]
		app.launch()

		let signIn = app.buttons["SIGN IN"]
		XCTAssertTrue(signIn.waitForExistence(timeout: 10))
		XCTAssertTrue(signIn.isHittable)

		// Scrolled into view, not just asserted hittable in place: at
		// accessibility5 the form alone can exceed the screen height, and
		// reaching content below the fold by scrolling is the accessible
		// path here, not a layout bug — `signIn` above already confirms the
		// screen's first control is reachable without scrolling at all.
		let signUp = app.buttons["SIGN ME UP"]
		XCTAssertTrue(signUp.waitForExistence(timeout: 10))
		app.scrollViews.firstMatch.swipeUp()
		XCTAssertTrue(signUp.isHittable)
	}

	func testPlacesNearbyUsableAtAccessibility5() {
		let app = UITestLaunching.launchSignedIn(contentSizeCategory: UITestLaunching.accessibility5ContentSizeCategory)

		let venueCell = UITestLaunching.element(labeled: "Fixture Venue", in: app)
		XCTAssertTrue(venueCell.waitForExistence(timeout: 10))
		XCTAssertTrue(venueCell.isHittable)

		let profileTab = UITestLaunching.tabBarButton(named: "Profile", in: app)
		XCTAssertTrue(profileTab.waitForExistence(timeout: 10))
		XCTAssertTrue(profileTab.isHittable)
	}
}
