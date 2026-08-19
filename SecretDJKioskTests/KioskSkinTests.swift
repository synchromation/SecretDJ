import DesignSystem
import Foundation
import SecretDJAPI
import Testing

@testable import SecretDJKiosk

/// ``KioskSkin`` — D10's chrome reconciliation: the manifest's typed color
/// roles are honored, DesignSystem owns everything it doesn't cover, and a
/// text-bearing pairing (toast text on toast background — the one solid
/// skin-color pairing this build renders text over) that fails WCAG AA
/// falls back to ``Theme``'s own already-sanctioned pairing rather than
/// rendering illegible chrome for an untrusted or malformed skin.
enum KioskSkinTests {
	struct `Toast resolution` {
		@Test func `uses the skin's own colors when they clear 4_5 to 1 contrast`() throws {
			let manifest = try SkinManifestFixture.make(properties: [
				1010: "#FF000000", // opaque black background
				1011: "#FFFFFFFF", // opaque white text — passes against black
			])

			let skin = KioskSkin.resolve(manifest: manifest, imageFileURLs: [:])

			#expect(skin.toast.background == .skin(Theme.RGBAComponents(red: 0, green: 0, blue: 0, alpha: 1)))
			#expect(skin.toast.text == .skin(Theme.RGBAComponents(red: 1, green: 1, blue: 1, alpha: 1)))
		}

		@Test func `falls back to the theme's own toast pairing when the skin's contrast fails`() throws {
			let manifest = try SkinManifestFixture.make(properties: [
				1010: "#FFFFFFFF", // white background
				1011: "#FFF8F8F8", // near-white text — fails against white
			])

			let skin = KioskSkin.resolve(manifest: manifest, imageFileURLs: [:])

			#expect(skin.toast.background == .themeFallback(.toastSurface))
			#expect(skin.toast.text == .themeFallback(.toastText))
		}

		@Test func `falls back to the theme's own toast pairing when the manifest has no toast at all`() throws {
			let manifest = try SkinManifestFixture.make()

			let skin = KioskSkin.resolve(manifest: manifest, imageFileURLs: [:])

			#expect(skin.toast.background == .themeFallback(.toastSurface))
			#expect(skin.toast.text == .themeFallback(.toastText))
		}

		@Test func `falls back to the theme's own toast pairing when a color fails to parse`() throws {
			let manifest = try SkinManifestFixture.make(properties: [
				1010: "not-a-color",
				1011: "#FFFFFFFF",
			])

			let skin = KioskSkin.resolve(manifest: manifest, imageFileURLs: [:])

			#expect(skin.toast.background == .themeFallback(.toastSurface))
			#expect(skin.toast.text == .themeFallback(.toastText))
		}

		@Test func `carries the skin's border color and width independent of the text contrast check`() throws {
			let manifest = try SkinManifestFixture.make(properties: [
				1010: "#FF000000",
				1011: "#FFFFFFFF",
				1012: "#FF00FF00",
				1013: "2",
			])

			let skin = KioskSkin.resolve(manifest: manifest, imageFileURLs: [:])

			#expect(skin.toast.border == .skin(Theme.RGBAComponents(red: 0, green: 1, blue: 0, alpha: 1)))
			#expect(skin.toast.borderWidth == 2)
		}

		@Test func `has no border when the manifest omits one`() throws {
			let manifest = try SkinManifestFixture.make()

			let skin = KioskSkin.resolve(manifest: manifest, imageFileURLs: [:])

			#expect(skin.toast.border == nil)
			#expect(skin.toast.borderWidth == nil)
		}
	}

	struct `Header chrome` {
		@Test func `resolves the now-playing tint from the skin's color when present`() throws {
			let manifest = try SkinManifestFixture.make(properties: [1151: "#FFFCC129"])

			let skin = KioskSkin.resolve(manifest: manifest, imageFileURLs: [:])

			#expect(
				skin.headerTint ==
					.skin(Theme.RGBAComponents(red: 0xFC / 255, green: 0xC1 / 255, blue: 0x29 / 255, alpha: 1)),
			)
		}

		@Test func `falls back to the theme's accent when the skin has no tint`() throws {
			let manifest = try SkinManifestFixture.make()

			let skin = KioskSkin.resolve(manifest: manifest, imageFileURLs: [:])

			#expect(skin.headerTint == .themeFallback(.accent))
		}

		@Test func `resolves the header background image from the now-playing-background asset id`() throws {
			let manifest = try SkinManifestFixture.make()
			let localURL = URL(fileURLWithPath: "/tmp/01001@2x.png")

			let skin = KioskSkin.resolve(manifest: manifest, imageFileURLs: [1001: localURL])

			#expect(skin.headerBackgroundImageURL == localURL)
		}

		@Test func `passes the manifest's header height through unchanged`() throws {
			let manifest = try SkinManifestFixture.make(properties: [1003: "150"])

			let skin = KioskSkin.resolve(manifest: manifest, imageFileURLs: [:])

			#expect(skin.headerHeight == 150)
		}

		@Test func `has no header height when the manifest omits one`() throws {
			let manifest = try SkinManifestFixture.make()

			let skin = KioskSkin.resolve(manifest: manifest, imageFileURLs: [:])

			#expect(skin.headerHeight == nil)
		}
	}

	struct `Resolved color rendering` {
		/// A `.themeFallback` case's `.color` isn't separately asserted here:
		/// `Theme.ColorRole.color` resolves to a dynamic, appearance-adaptive
		/// `Color` (`Color(UIColor { traits in ... })`), and two independently
		/// resolved dynamic colors aren't guaranteed `Equatable`-equal even
		/// when built from the same role — the case-level equality already
		/// asserted throughout `Toast resolution`/`Header chrome` (e.g.
		/// `skin.headerTint == .themeFallback(.accent)`) is the reliable,
		/// meaningful check for that path.
		@Test func `a skin color renders its own literal color`() {
			let resolved = ResolvedSkinColor.skin(Theme.RGBAComponents(red: 1, green: 0, blue: 0, alpha: 1))

			#expect(resolved.color == Theme.RGBAComponents(red: 1, green: 0, blue: 0, alpha: 1).color)
		}
	}
}
