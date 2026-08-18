import AVFoundation
import DesignSystem
import Observability
import PhotosUI
import SecretDJAPI
import SwiftUI
import UIKit

/// Every route's final, mandatory onboarding step: a profile photo, picked
/// from the library or captured with the camera (LEGACY.md "Login, sign-up,
/// onboarding" — `secretdjv3/LoginProfilePictureViewController.swift`,
/// always constructed with `photoIsOptional: false`, so — unlike legacy's
/// interactive pinch/pan crop — this step never offers a skip; uploading
/// starts automatically once a photo is chosen).
struct PhotoStepView: View {
	let model: OnboardingModel

	@State private var pickerItem: PhotosPickerItem?
	@State private var showsCamera = false
	@State private var showsCameraPermissionAlert = false
	@State private var toastQueue = DesignSystem.ToastQueue()

	var body: some View {
		ScrollView {
			VStack(spacing: Spacing.large) {
				Text("Add a profile picture")
					.font(Theme.TextStyle.screenTitle.font)
					.foregroundStyle(Theme.ColorRole.primaryText.color)

				Text("Everyone signing up needs one — it's how people recognize you.")
					.font(Theme.TextStyle.body.font)
					.foregroundStyle(Theme.ColorRole.secondaryText.color)
					.multilineTextAlignment(.center)

				pickerButton
				cameraButton

				if model.isSubmitting {
					ProgressView()
				}

				if let errorMessage = model.errorMessage {
					errorText(errorMessage)
				}
			}
			.padding(Spacing.large)
		}
		.background(Theme.ColorRole.background.color)
		.tracksScreen("OnboardingPhoto")
		.toastPresenter(queue: toastQueue)
		.onChange(of: model.rewardMessage) { _, newValue in
			if let newValue {
				toastQueue.enqueue(ToastItem(message: newValue))
			}
		}
		.onChange(of: pickerItem) { _, newValue in
			guard let newValue else {
				return
			}

			Task {
				await upload(newValue)
			}
		}
		.sheet(isPresented: $showsCamera) {
			CameraCapture { image in
				showsCamera = false
				if let image {
					uploadCaptured(image)
				}
			}
		}
		.alert(
			"Camera Access Needed",
			isPresented: $showsCameraPermissionAlert,
		) {
			Button("Open Settings") {
				openSettings()
			}
			Button("Cancel", role: .cancel) {}
		} message: {
			Text("To take a profile picture, allow Secret DJ to use your camera in Settings.")
		}
	}

	private var pickerButton: some View {
		PhotosPicker(selection: $pickerItem, matching: .images) {
			Text("Choose from Library")
				.frame(maxWidth: .infinity)
		}
		.buttonStyle(.primary)
		.disabled(model.isSubmitting)
	}

	private var cameraButton: some View {
		Button {
			requestCameraAccess()
		} label: {
			Text("Take a Photo")
				.frame(maxWidth: .infinity)
		}
		.buttonStyle(.secondary)
		.disabled(model.isSubmitting)
	}

	private func errorText(_ message: String) -> some View {
		Text(message)
			.font(Theme.TextStyle.body.font)
			.foregroundStyle(Theme.ColorRole.danger.color)
			.multilineTextAlignment(.center)
			.accessibilityAddTraits(.updatesFrequently)
	}

	private func requestCameraAccess() {
		switch AVCaptureDevice.authorizationStatus(for: .video) {
		case .authorized:
			showsCamera = true

		case .notDetermined:
			Task {
				let granted = await AVCaptureDevice.requestAccess(for: .video)
				if granted {
					showsCamera = true
				} else {
					showsCameraPermissionAlert = true
				}
			}

		case .denied,
		     .restricted:
			showsCameraPermissionAlert = true

		@unknown default:
			showsCameraPermissionAlert = true
		}
	}

	private func openSettings() {
		guard let url = URL(string: UIApplication.openSettingsURLString) else {
			return
		}

		UIApplication.shared.open(url)
	}

	private func upload(_ item: PhotosPickerItem) async {
		guard let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data),
		      let processed = AvatarImageProcessing.downscaledJPEGData(from: image) else
		{
			return
		}

		await model.uploadPhoto(processed)
	}

	private func uploadCaptured(_ image: UIImage) {
		guard let processed = AvatarImageProcessing.downscaledJPEGData(from: image) else {
			return
		}

		Task {
			await model.uploadPhoto(processed)
		}
	}
}

/// A `UIImagePickerController` camera capture, wrapped for SwiftUI. The
/// simplest fully-supported way to reach the camera — AVFoundation-backed
/// under the hood, without building a custom `AVCaptureSession` preview.
private struct CameraCapture: UIViewControllerRepresentable {
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

#Preview("Fresh") {
	PhotoStepView(model: OnboardingModel(
		route: .native,
		personId: "9",
		credential: APICredential(token: "tok", passwordHash: "hash"),
		onboardingService: InMemoryOnboardingService(),
		sessionStore: PreviewSessionStore.signedOut(),
	))
}

#Preview("Uploading") {
	let model = OnboardingModel(
		route: .native,
		personId: "9",
		credential: APICredential(token: "tok", passwordHash: "hash"),
		onboardingService: InMemoryOnboardingService(),
		sessionStore: PreviewSessionStore.signedOut(),
	)
	return PhotoStepView(model: model)
}

#Preview("Error") {
	PhotoStepView(model: OnboardingModel(
		route: .native,
		personId: "9",
		credential: APICredential(token: "tok", passwordHash: "hash"),
		onboardingService: InMemoryOnboardingService(
			uploadAvatarResult: .failure(.server(message: "That image is too large.")),
		),
		sessionStore: PreviewSessionStore.signedOut(),
	))
}

#Preview("Accessibility text size") {
	PhotoStepView(model: OnboardingModel(
		route: .native,
		personId: "9",
		credential: APICredential(token: "tok", passwordHash: "hash"),
		onboardingService: InMemoryOnboardingService(),
		sessionStore: PreviewSessionStore.signedOut(),
	))
	.environment(\.dynamicTypeSize, .accessibility5)
}
