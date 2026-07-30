import CoreGraphics

public struct JCSInsets: Sendable, Codable, CustomStringConvertible {
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
}
