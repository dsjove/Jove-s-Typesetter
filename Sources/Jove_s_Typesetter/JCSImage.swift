import CoreGraphics
import UIKit

public struct JCSImage: JCSDrawable {
	public let source: JCSImageSource
	public let cornerRadius: CGFloat
	public let aspect: JCSAspect
	public let align: JCSAlign
	public let image: UIImage?

	public init(
		_ source: JCSImageSource,
		aspect: JCSAspect = .fit,
		align: JCSAlign = .center,
		cornerRadius: CGFloat = 0.0
	) {
		self.source = source
		self.cornerRadius = cornerRadius
		self.aspect = aspect
		self.align = align
		self.image = source.image
	}

	public var isEmpty: Bool {
		image == nil
	}

	public func measure(bounds: CGSize) -> CGSize {
		aspect.apply(size: image?.size ?? .zero, in: bounds)
	}

	public func draw(in rect: CGRect) {
		if let image = image {
			let sized = aspect.apply(size: image.size, in: rect.size)
			let placed = align.apply(size: sized, in: rect)
			if let ctx = UIGraphicsGetCurrentContext() {
				ctx.saveGState()
				defer { ctx.restoreGState() }
				if cornerRadius > 0 {
					let path = CGPath(roundedRect: placed, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
					ctx.addPath(path)
					ctx.clip()
				}
				image.draw(in: placed)
			}
		}
	}
}
