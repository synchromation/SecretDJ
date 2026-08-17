import Foundation

extension Theme {
	/// A color's explicit sRGB components — the single source of truth both
	/// the resolved SwiftUI `Color` and the contrast-ratio math are derived
	/// from, so a color's contrast can be tested without touching an opaque
	/// `Color`.
	public struct RGBAComponents: Equatable, Hashable, Sendable {
		public let red: Double
		public let green: Double
		public let blue: Double
		public let alpha: Double

		public init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
			self.red = red
			self.green = green
			self.blue = blue
			self.alpha = alpha
		}
	}
}

extension Theme.RGBAComponents {
	/// The WCAG relative luminance of this color, from 0 (black) to 1 (white),
	/// per the sRGB-to-linear formula in WCAG 2.x success criterion 1.4.3.
	public var relativeLuminance: Double {
		func linearize(_ channel: Double) -> Double {
			channel <= 0.03928 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
		}

		return 0.2126 * linearize(red) + 0.7152 * linearize(green) + 0.0722 * linearize(blue)
	}

	/// The WCAG contrast ratio (1...21) between this color and `other`,
	/// independent of which of the two is lighter.
	public func contrastRatio(against other: Theme.RGBAComponents) -> Double {
		let (lighter, darker) = relativeLuminance >= other.relativeLuminance
			? (relativeLuminance, other.relativeLuminance)
			: (other.relativeLuminance, relativeLuminance)

		return (lighter + 0.05) / (darker + 0.05)
	}
}
