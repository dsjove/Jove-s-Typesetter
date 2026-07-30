import CoreGraphics

public enum JCSDimension: CustomStringConvertible {
	case fixed(_ value: CGFloat)
	case intrinsic(bound: CGFloat = .unbounded, min: CGFloat? = nil)
	case fill(_ fraction: CGFloat? = nil)
	case uniform(_ reduce: (CGFloat, CGFloat)->CGFloat = max)

	public var description: String {
		switch self {
		case .fixed(let value):
			"fixed(\(value.unboundedDescription))"
		case .intrinsic(let bound, let min):
			"intrinsic(\(min ?? 0.0)...\(bound.unboundedDescription))"
		case .uniform:
			"uniform(∑)"
		case .fill(let fraction):
			"fill\(fraction?.description ?? "⋯")"
		}
	}

	//TODO: Design - can we have generic apply method that reads an array of elements with property path and then calls a setter?
}
