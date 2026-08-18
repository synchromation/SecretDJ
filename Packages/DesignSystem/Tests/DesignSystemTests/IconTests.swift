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
}
