import CoreGraphics
import DesignSystem

extension ResolvedToastAppearance {
	/// This resolved chrome as the ``DesignSystem/ToastAppearance``
	/// `toastPresenter(queue:appearance:)` takes — ``KioskSkin/toast`` was
	/// resolved (colors picked, contrast checked) at S7.2; this is just the
	/// type conversion S7.4/S7.5 needs to actually hand it to the shared
	/// toast presenter.
	var toastAppearance: ToastAppearance {
		ToastAppearance(
			background: background.color,
			text: text.color,
			border: border?.color,
			borderWidth: borderWidth.map(CGFloat.init),
		)
	}
}
