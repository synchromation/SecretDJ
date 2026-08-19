import SwiftUI
import UIKit

/// A `UIImagePickerController` camera capture, wrapped for SwiftUI. The
/// simplest fully-supported way to reach the camera — AVFoundation-backed
/// under the hood, without building a custom `AVCaptureSession` preview.
/// Shared by every avatar-picking flow (S4.5's onboarding photo step, S6.3b's
/// pic-for-credits upsell) via ``AvatarPickerButtons``.
struct CameraCapture: UIViewControllerRepresentable {
	let onCapture: (UIImage?) -> Void

	func makeUIViewController(context: Context) -> UIImagePickerController {
		let controller = UIImagePickerController()
		controller.sourceType = .camera
		controller.delegate = context.coordinator
		return controller
	}

	func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

	func makeCoordinator() -> Coordinator {
		Coordinator(onCapture: onCapture)
	}

	final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
		private let onCapture: (UIImage?) -> Void

		init(onCapture: @escaping (UIImage?) -> Void) {
			self.onCapture = onCapture
		}

		func imagePickerController(
			_ picker: UIImagePickerController,
			didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any],
		) {
			onCapture(info[.originalImage] as? UIImage)
		}

		func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
			onCapture(nil)
		}
	}
}
