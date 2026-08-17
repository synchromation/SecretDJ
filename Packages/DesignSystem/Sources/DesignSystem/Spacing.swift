import CoreGraphics

/// The semantic spacing scale shared by every view in this design system, so
/// spacing stays consistent instead of ad hoc per screen.
public enum Spacing {
	/// The smallest spacing step, for tight groupings like an icon and its label.
	public static let extraSmall: CGFloat = 4

	/// Default spacing between closely related elements.
	public static let small: CGFloat = 8

	/// Spacing between distinct groups of content.
	public static let medium: CGFloat = 16

	/// Spacing that separates major sections of a screen.
	public static let large: CGFloat = 24
}
