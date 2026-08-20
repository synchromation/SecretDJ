import XCTest

/// Shared launch/navigation helpers for every ``SecretDJKioskUITests``
/// suite (PLAN.md S8.2) — mirrors the consumer target's own
/// `UITestLaunching` (`SecretDJUITests/UITestLaunching.swift`). Every test
/// launches through here rather than calling `XCUIApplication().launch()`
/// directly, so the `UITEST_MODE`/`UITEST_SIGNED_IN` launch-environment
/// contract (`SecretDJKiosk/Support/UITesting/UITestMode.swift`) lives in
/// exactly one place: the app never touches the real network under this
/// contract.
///
/// `nonisolated`: `XCUIApplication`/`XCUIElement` are plain, non-actor-
/// isolated XCTest types (predating Swift concurrency), so this stays off
/// the main actor the project's `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`
/// setting would otherwise default it onto — matching the `nonisolated`
/// test classes that call it.
nonisolated enum UITestLaunching {
	/// Launches the kiosk in UI-test mode, signed out — shows venue sign-in.
	/// Forces landscape first: the kiosk is landscape-only (PLAN.md S8.2
	/// "Landscape for kiosk"), and the simulator can otherwise still boot a
	/// fresh session in portrait before the app's own orientation lock
	/// takes effect.
	static func launchSignedOut() -> XCUIApplication {
		XCUIDevice.shared.orientation = .landscapeLeft
		let app = XCUIApplication()
		app.launchEnvironment["UITEST_MODE"] = "1"
		app.launch()
		return app
	}

	/// Launches the kiosk in UI-test mode, already checked into the fixture
	/// venue with its skin pre-seeded — shows the home/digest screen
	/// directly. `contentSizeCategory` applies
	/// `-UIPreferredContentSizeCategoryName` when set, for the Dynamic Type
	/// walk (PLAN.md S8.2).
	static func launchSignedIn(contentSizeCategory: String? = nil) -> XCUIApplication {
		XCUIDevice.shared.orientation = .landscapeLeft
		let app = XCUIApplication()
		app.launchEnvironment["UITEST_MODE"] = "1"
		app.launchEnvironment["UITEST_SIGNED_IN"] = "1"
		if let contentSizeCategory {
			app.launchArguments += ["-UIPreferredContentSizeCategoryName", contentSizeCategory]
		}
		app.launch()
		return app
	}

	/// The launch argument value for accessibility5 (`AX5`, the largest
	/// Dynamic Type step) — `DynamicTypeSize.accessibility5`'s own UIKit
	/// content-size-category name.
	static let accessibility5ContentSizeCategory = "UICTContentSizeCategoryAccessibilityXXXL"

	/// Finds the first element anywhere in `app` whose accessibility label
	/// contains `text` — feed cells compose several lines of copy into one
	/// label (per the accessibility skill's "combine" rule), so an exact
	/// match is too brittle; this is what every fixture-content lookup in
	/// this target uses instead.
	static func element(labeled text: String, in app: XCUIApplication) -> XCUIElement {
		app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS[c] %@", text)).firstMatch
	}

	/// A *tappable* fixture element by label — the kiosk's now-playing
	/// header shows the same song title as plain, non-interactive text
	/// (``KioskNowPlayingHeaderView``) while the digest below shows it again
	/// as a real cell, so a bare label match (``element(labeled:in:)``) can
	/// land on the wrong one. Waits for a `.buttons` match (what a tappable
	/// feed cell exposes) first, falling back to the generic lookup only if
	/// no button ever appears.
	static func waitForTappableElement(
		labeled text: String,
		in app: XCUIApplication,
		timeout: TimeInterval,
	) -> XCUIElement {
		let button = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", text)).firstMatch
		if button.waitForExistence(timeout: timeout) {
			return button
		}
		return element(labeled: text, in: app)
	}

	/// Runs the accessibility audit, printing every issue found (element and
	/// description) to the test log before deciding whether to allow it —
	/// mirrors the consumer target's own
	/// `UITestLaunching.performAccessibilityAudit(on:)`, including its
	/// documented, investigated ``knownIssues`` remainder; anything not on
	/// that list still fails the test.
	static func performAccessibilityAudit(on app: XCUIApplication) throws {
		try app.performAccessibilityAudit { issue in
			print(
				"[A11Y AUDIT] \(issue.compactDescription) — \(issue.detailedDescription) — element: \(issue.element?.label ?? "(none)")",
			)
			return knownIssues
				.contains {
					$0.compactDescription == issue
						.compactDescription && ($0.elementLabel == nil || $0.elementLabel == issue.element?.label)
				}
		}
	}

	/// One documented, accepted audit issue: a `compactDescription`, and
	/// either the one `elementLabel` it's confined to, or `nil` to allow
	/// every element the handler above sees under that category.
	private struct KnownIssue {
		let compactDescription: String
		let elementLabel: String?
	}

	/// S8.2's documented remainder for this target — mirrors the consumer
	/// target's own two systemic categories (`SecretDJUITests/UITestLaunching.swift`'s
	/// own doc comment has the full investigation): "Text clipped" on
	/// `SwiftUI.UIKitTextField` (seen here on the "Venue password"
	/// `SecureField`; `KioskSignInView.swift`'s own `// S8.2-FOLLOWUP:`
	/// comment) and "Dynamic Type font sizes are partially unsupported"
	/// (the shared `FeedSectionHeader`, reused wholesale by this app's own
	/// digest screen) — both allowed for every element, since the consumer
	/// target's investigation already ruled out a single element-specific
	/// cause for either.
	private static let knownIssues: [KnownIssue] = [
		KnownIssue(compactDescription: "Text clipped", elementLabel: nil),
		KnownIssue(compactDescription: "Dynamic Type font sizes are partially unsupported", elementLabel: nil),
	]
}
