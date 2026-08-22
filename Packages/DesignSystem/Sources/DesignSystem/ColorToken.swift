import SwiftUI

#if canImport(UIKit)
	import UIKit
#elseif canImport(AppKit)
	import AppKit
#endif

extension Theme {
	/// A color resolved separately for light and dark appearance.
	public struct ColorToken: Equatable, Sendable {
		public let light: RGBAComponents
		public let dark: RGBAComponents

		public init(light: RGBAComponents, dark: RGBAComponents) {
			self.light = light
			self.dark = dark
		}
	}
}

extension Theme.ColorToken {
	/// The dynamic SwiftUI color that resolves to `light` or `dark` for the
	/// current appearance.
	public var color: Color {
		#if canImport(UIKit)
			Color(UIColor { traits in
				traits.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
			})
		#elseif canImport(AppKit)
			Color(NSColor(name: nil) { appearance in
				appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? NSColor(dark) : NSColor(light)
			})
		#else
			Color(red: light.red, green: light.green, blue: light.blue, opacity: light.alpha)
		#endif
	}

	#if canImport(UIKit)
		/// The dynamic `UIColor` counterpart to ``color`` — for call sites
		/// (a `UINavigationBarAppearance`'s `titleTextAttributes`, e.g.) that
		/// take a `UIColor` rather than a SwiftUI `Color`.
		var uiColor: UIColor {
			UIColor { traits in
				traits.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
			}
		}
	#endif
}

#if canImport(UIKit)
	extension UIColor {
		fileprivate convenience init(_ components: Theme.RGBAComponents) {
			self.init(
				red: CGFloat(components.red),
				green: CGFloat(components.green),
				blue: CGFloat(components.blue),
				alpha: CGFloat(components.alpha),
			)
		}
	}

#elseif canImport(AppKit)
	extension NSColor {
		fileprivate convenience init(_ components: Theme.RGBAComponents) {
			self.init(
				srgbRed: CGFloat(components.red),
				green: CGFloat(components.green),
				blue: CGFloat(components.blue),
				alpha: CGFloat(components.alpha),
			)
		}
	}
#endif
