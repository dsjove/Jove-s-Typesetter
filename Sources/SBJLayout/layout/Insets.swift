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
		size.inset(
			dx: (left + right) * (inverse ? -1 : 1),
			dy: (top + bottom) * (inverse ? -1 : 1))
	}

	public func apply(rect: CGRect, inverse: Bool = false) -> CGRect {
		rect.inset(
			left: left * (inverse ? -1 : 1),
			top: top * (inverse ? -1 : 1),
			right: right * (inverse ? -1 : 1),
			bottom: bottom * (inverse ? -1 : 1))
	}
}
