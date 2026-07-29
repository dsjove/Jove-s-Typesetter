import CoreGraphics

public enum JCSSize: Sendable, Codable, CustomStringConvertible {
	case fixed(_ value: CGFloat)
	case intrinsic(bound: CGFloat = .unbounded, min: CGFloat? = nil)
	case fill(_ fraction: CGFloat? = nil)
	case uniform

	public var description: String {
		switch self {
		case .fixed(let value):
			"fixed(\(value.unboundedDescription))"
		case .intrinsic(let bound, let min):
			"intrinsic(\(min ?? 0.0)...\(bound.unboundedDescription))"
		case .uniform:
			"uniform"
		case .fill(let fraction):
			"fill\(fraction?.description ?? "⋯")"
		}
	}
}
