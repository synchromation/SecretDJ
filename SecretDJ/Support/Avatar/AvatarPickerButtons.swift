import AVFoundation
import DesignSystem
import PhotosUI
import SwiftUI

/// The "Choose from Library" / "Take a Photo" pair every avatar-picking flow
/// needs (LEGACY.md "Login, sign-up, onboarding" —
/// `secretdjv3/LoginProfilePictureViewController.swift`'s picker/camera
/// pair): downscales and JPEG-encodes whatever the user picks
/// (``AvatarImageProcessing``) before handing it to `onImageData`. Extracted
/// from S4.5's ``PhotoStepView`` for S6.3b so the pic-for-credits upsell
/// (LEGACY.md business rule 5, no profile picture branch) can reuse the
/// identical picker UI rather than duplicating it.
struct AvatarPickerButtons: View {
	let isSubmitting: Bool
	let onImageData: (Data) -> Void

	@State private var pickerItem: PhotosPickerItem?
	@State private var showsCamera = false
	@State private var showsCameraPermissionAlert = false

	var body: some View {
		VStack(spacing: Spacing.medium) {
			pickerButton
			cameraButton
		}
		.onChange(of: pickerItem) { _, newValue in
			guard let newValue else { return }

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
		.disabled(isSubmitting)
	}

	private var cameraButton: some View {
		Button {
			requestCameraAccess()
		} label: {
			Text("Take a Photo")
				.frame(maxWidth: .infinity)
		}
		.buttonStyle(.secondary)
		.disabled(isSubmitting)
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

		onImageData(processed)
	}

	private func uploadCaptured(_ image: UIImage) {
		guard let processed = AvatarImageProcessing.downscaledJPEGData(from: image) else {
			return
		}

		onImageData(processed)
	}
}

#Preview {
	AvatarPickerButtons(isSubmitting: false, onImageData: { _ in })
		.padding()
}
