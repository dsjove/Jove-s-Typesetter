import CoreGraphics

public struct JCSInsets: Sendable, Codable, CustomStringConvertible {
	public var left: CGFloat = 0.0
	public var right: CGFloat = 0.0
	public var top: CGFloat = 0.0
	public var bottom: CGFloat = 0.0

	public var description: String {
		"(left: \(left), right: \(right), top: \(top), bottom: \(bottom))"
	}
}
