import CoreGraphics

public enum TrackSize: CustomStringConvertible {
	case fixed(_ value: CGFloat)
	case intrinsic(bound: CGFloat = .unbounded, min: CGFloat? = nil)
	case fill(_ fraction: CGFloat? = nil, min :CGFloat = 0, max: CGFloat = .unbounded)
	case uniform(_ reduce: (CGFloat, CGFloat)->CGFloat = max)

	public var description: String {
		switch self {
		case .fixed(let value):
			"fixed(\(value.unboundedDescription))"
		case .intrinsic(let bound, let min):
			"intrinsic(\(min ?? 0.0)...\(bound.unboundedDescription))"
		case .uniform:
			"uniform(∑)"
		case .fill(let fraction, let minimum, let maximum):
			"fill\(fraction?.description ?? "1/C") \(minimum)…\(maximum.unboundedDescription)"
		}
	}
}
