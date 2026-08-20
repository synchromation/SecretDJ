import XCTest

/// Launches at accessibility5 (`-UIPreferredContentSizeCategoryName`, the
/// largest Dynamic Type step) and asserts key kiosk screens stay usable —
/// mirrors the consumer target's own `DynamicTypeTests`
/// (`SecretDJUITests/DynamicTypeTests.swift`). PLAN.md S8.2: "Dynamic Type
/// through accessibility5".
///
/// `nonisolated` on the class: see `AccessibilityAuditTests`'s own doc
/// comment — the project's `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`
/// setting would otherwise conflict with `XCTestCase`'s nonisolated
/// designated initializers.
final nonisolated class DynamicTypeTests: XCTestCase {
	override func setUpWithError() throws {
		continueAfterFailure = false
	}

	func testVenueSignInUsableAtAccessibility5() {
		XCUIDevice.shared.orientation = .landscapeLeft
		let app = XCUIApplication()
		app.launchEnvironment["UITEST_MODE"] = "1"
		app.launchArguments += [
			"-UIPreferredContentSizeCategoryName", UITestLaunching.accessibility5ContentSizeCategory,
		]
		app.launch()

		let signIn = app.buttons["SIGN IN"]
		XCTAssertTrue(signIn.waitForExistence(timeout: 10))
		XCTAssertTrue(signIn.isHittable)
	}

	func testHomeDigestUsableAtAccessibility5() {
		let app = UITestLaunching.launchSignedIn(contentSizeCategory: UITestLaunching.accessibility5ContentSizeCategory)

		let search = app.buttons["Search"]
		XCTAssertTrue(search.waitForExistence(timeout: 15))
		XCTAssertTrue(search.isHittable)
	}
}
