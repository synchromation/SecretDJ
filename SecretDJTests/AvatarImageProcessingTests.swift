import Testing
import UIKit

@testable import SecretDJ

struct AvatarImageProcessingTests {
	private func makeImage(width: CGFloat, height: CGFloat) -> UIImage {
		let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: {
			let format = UIGraphicsImageRendererFormat()
			format.scale = 1
			return format
		}())
		return renderer.image { context in
			UIColor.red.setFill()
			context.fill(CGRect(x: 0, y: 0, width: width, height: height))
		}
	}

	@Test func `a landscape image larger than 1024 on its cropped side is downscaled to exactly 1024x1024`() throws {
		let image = makeImage(width: 2000, height: 1500)

		let data = try #require(AvatarImageProcessing.downscaledJPEGData(from: image))
		let decoded = try #require(UIImage(data: data))

		#expect(decoded.size.width == 1024)
		#expect(decoded.size.height == 1024)
	}

	@Test func `a square image already under 1024 keeps its original size`() throws {
		let image = makeImage(width: 400, height: 400)

		let data = try #require(AvatarImageProcessing.downscaledJPEGData(from: image))
		let decoded = try #require(UIImage(data: data))

		#expect(decoded.size.width == 400)
		#expect(decoded.size.height == 400)
	}

	@Test func `a portrait image's crop uses the shorter width dimension`() throws {
		let image = makeImage(width: 300, height: 900)

		let data = try #require(AvatarImageProcessing.downscaledJPEGData(from: image))
		let decoded = try #require(UIImage(data: data))

		#expect(decoded.size.width == 300)
		#expect(decoded.size.height == 300)
	}

	@Test func `returns non-nil for a valid image`() {
		let image = makeImage(width: 100, height: 100)

		#expect(AvatarImageProcessing.downscaledJPEGData(from: image) != nil)
	}
}
