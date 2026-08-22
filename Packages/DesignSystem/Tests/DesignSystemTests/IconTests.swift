import Testing

#if canImport(AppKit)
	import AppKit
#elseif canImport(UIKit)
	import UIKit
#endif

@testable import DesignSystem

struct IconTests {
	@Test(arguments: Theme.Icon.allCases)
	func `every icon's SF Symbol name exists in the platform's symbol set`(icon: Theme.Icon) {
		#if canImport(AppKit)
			let symbolExists = NSImage(systemSymbolName: icon.systemName, accessibilityDescription: nil) != nil
		#elseif canImport(UIKit)
			let symbolExists = UIImage(systemName: icon.systemName) != nil
		#else
			let symbolExists = true
		#endif

		#expect(symbolExists)
	}

	// MARK: - Glyph context (nav buttons, inline badges, standalone controls)

	static let expectedGlyphAssetNames: [Theme.Icon: String] = [
		.search: "iconSearchDefault",
		.topUp: "iconTopupDefault",
		.taxi: "iconTaxiDefault",
		.map: "iconMapButton",
		.like: "iconLike",
		.likeFilled: "iconLikeSelected",
		.playPreview: "previewIcon",
		.stopPreview: "endPreviewIcon",
	]

	@Test(arguments: Theme.Icon.allCases)
	func `every role's glyph asset name matches its legacy-verified mapping, or nil when unverified`(
		icon: Theme.Icon,
	) {
		#expect(Theme.Icon.IconTestSeam.glyphAssetName(for: icon) == Self.expectedGlyphAssetNames[icon])
	}

	@Test(arguments: Array(expectedGlyphAssetNames.values))
	func `every glyph-backed role's legacy asset resolves in Bundle_module`(assetName: String) {
		#expect(imageExists(named: assetName))
	}

	// MARK: - Placeholder context (RemoteArtworkView's own fallback)

	static let expectedPlaceholderAssetNames: [Theme.Icon: String] = [
		.song: "placeholderTune",
		.venue: "placeholderVenue",
		.profile: "placeholderAvatarUnisex",
		.jukebox: "placeholderJukeboxBackground",
	]

	@Test(arguments: Theme.Icon.allCases)
	func `every role's placeholder asset name matches its legacy-verified mapping, or nil when unverified`(
		icon: Theme.Icon,
	) {
		#expect(Theme.Icon.IconTestSeam.placeholderAssetName(for: icon) == Self.expectedPlaceholderAssetNames[icon])
	}

	@Test(arguments: Array(expectedPlaceholderAssetNames.values))
	func `every placeholder-backed role's legacy asset resolves in Bundle_module`(assetName: String) {
		#expect(imageExists(named: assetName))
	}

	@Test(arguments: Theme.Icon.allCases)
	func `hasLegacyPlaceholder agrees with whether a placeholder asset name exists`(icon: Theme.Icon) {
		#expect(icon.hasLegacyPlaceholder == (Self.expectedPlaceholderAssetNames[icon] != nil))
	}

	// MARK: - Tab-bar context

	static let expectedTabAssetNames: [Theme.Icon: (unselected: String, selected: String)] = [
		.venue: ("iconTabVenueDefault", "iconTabVenueSelected"),
		.activity: ("iconTabBuzzDefault", "iconTabBuzzSelected"),
		.profile: ("iconTabProfileDefault", "iconTabProfileSelected"),
	]

	@Test(arguments: Theme.Icon.allCases)
	func `every role's tab asset names match its legacy-verified mapping, or nil when unverified`(icon: Theme.Icon) {
		let expected = Self.expectedTabAssetNames[icon]
		#expect(Theme.Icon.IconTestSeam.tabAssetName(for: icon, selected: false) == expected?.unselected)
		#expect(Theme.Icon.IconTestSeam.tabAssetName(for: icon, selected: true) == expected?.selected)
	}

	@Test(arguments: Theme.Icon.allCases)
	func `every tab role resolves an Image for both selection states`(icon: Theme.Icon) {
		let isTabRole = Self.expectedTabAssetNames[icon] != nil
		#expect((icon.tabImage(selected: false) != nil) == isTabRole)
		#expect((icon.tabImage(selected: true) != nil) == isTabRole)
	}

	@Test(arguments: Self.expectedTabAssetNames.values.flatMap { [$0.unselected, $0.selected] })
	func `every tab role's legacy asset resolves in Bundle_module`(assetName: String) {
		#expect(imageExists(named: assetName))
	}

	// MARK: - Venue-map pin context

	static let expectedMapPinAssetNames: [Theme.Icon: String] = [
		.venue: "mapPinVenue",
		.jukebox: "mapPinVenueJukebox",
	]

	@Test(arguments: Theme.Icon.allCases)
	func `every role's map pin asset name matches its legacy-verified mapping, or nil when unverified`(
		icon: Theme.Icon,
	) {
		#expect(Theme.Icon.IconTestSeam.mapPinAssetName(for: icon) == Self.expectedMapPinAssetNames[icon])
		#expect((icon.mapPinImage != nil) == (Self.expectedMapPinAssetNames[icon] != nil))
	}

	@Test(arguments: Array(expectedMapPinAssetNames.values))
	func `every map pin role's legacy asset resolves in Bundle_module`(assetName: String) {
		#expect(imageExists(named: assetName))
	}
}

/// Cross-platform "does this named asset actually exist in `Bundle.module`"
/// check (this package also builds for macOS/visionOS in `swift test` —
/// swiftui-views/documentation skills' cross-platform rule) — the same
/// platform gate this file's own SF Symbol test already uses.
private func imageExists(named name: String) -> Bool {
	#if canImport(AppKit)
		Bundle.module.image(forResource: name) != nil
	#elseif canImport(UIKit)
		UIImage(named: name, in: .module, compatibleWith: nil) != nil
	#else
		true
	#endif
}
