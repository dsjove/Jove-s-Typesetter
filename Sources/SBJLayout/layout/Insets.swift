import CoreGraphics

public struct Insets: Sendable, Codable, CustomStringConvertible {
	public let left: CGFloat
	public let right: CGFloat
	public let top: CGFloat
	public let bottom: CGFloat

	public init(left: CGFloat = 0, right: CGFloat = 0, top: CGFloat = 0, bottom: CGFloat = 0) {
		self.left = left
		self.right = right
		self.top = top
		self.bottom = bottom
	}

	public var description: String {
		"(left: \(left), right: \(right), top: \(top), bottom: \(bottom))"
	}

	public func apply(size: CGSize, inverse: Bool = false) -> CGSize {
		let multiplier: CGFloat = inverse ? -1 : 1
		return .init(
			width: size.width.isUnbounded
				? size.width
				: size.width - ((left + right) * multiplier),
			height: size.height.isUnbounded
				? size.height
				: size.height - ((top + bottom) * multiplier)
		)
	}

	public func apply(rect: CGRect, inverse: Bool = false) -> CGRect {
		let multiplier: CGFloat = inverse ? -1 : 1
		return rect.inset(
			left: left * multiplier,
			top: top * multiplier,
			right: right * multiplier,
			bottom: bottom * multiplier)
	}
}
