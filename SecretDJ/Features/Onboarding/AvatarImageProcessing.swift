import UIKit

/// Ports the legacy avatar-upload invariants
/// (`AppConfiguration.shared.profilePictureJpegQuality`/`maxProfilePicSize`,
/// `secretdjv3/ImageResizeView.swift`'s `resizeImage()`) without its
/// interactive pinch/pan crop UI: every photo is centre-cropped to a square
/// and capped at ``maxDimension`` before being JPEG-encoded for `newavatar`.
/// UIKit-based on purpose — this is an app-target file, not a package (see
/// `APIClient+User.swift`'s doc comment: image encoding stays with the
/// caller).
enum AvatarImageProcessing {
	/// The legacy client's `maxProfilePicSize` — the encoded image never
	/// exceeds this on either dimension, and is never upscaled past it.
	static let maxDimension: CGFloat = 1024
	/// The legacy client's `profilePictureJpegQuality`.
	static let jpegQuality: CGFloat = 0.9

	/// Centre-crops `image` to a square (side = the shorter of its two
	/// dimensions), scales it down to fit ``maxDimension`` × ``maxDimension``
	/// when the cropped square is larger (never upscales), and JPEG-encodes
	/// the result at ``jpegQuality``.
	static func downscaledJPEGData(from image: UIImage) -> Data? {
		guard let cropped = croppedToSquare(image) else {
			return nil
		}

		let resized = downscaledIfNeeded(cropped)
		return resized.jpegData(compressionQuality: jpegQuality)
	}

	private static func croppedToSquare(_ image: UIImage) -> UIImage? {
		guard let cgImage = image.cgImage else {
			return nil
		}

		let pixelWidth = CGFloat(cgImage.width)
		let pixelHeight = CGFloat(cgImage.height)
		let side = min(pixelWidth, pixelHeight)
		let origin = CGPoint(x: (pixelWidth - side) / 2, y: (pixelHeight - side) / 2)

		guard let croppedCGImage = cgImage
			.cropping(to: CGRect(origin: origin, size: CGSize(width: side, height: side))) else
		{
			return nil
		}

		return UIImage(cgImage: croppedCGImage, scale: image.scale, orientation: image.imageOrientation)
	}

	private static func downscaledIfNeeded(_ image: UIImage) -> UIImage {
		guard image.size.width > maxDimension else {
			return image
		}

		let targetSize = CGSize(width: maxDimension, height: maxDimension)
		let format = UIGraphicsImageRendererFormat()
		format.scale = 1
		let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
		return renderer.image { _ in
			image.draw(in: CGRect(origin: .zero, size: targetSize))
		}
	}
}
