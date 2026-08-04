import CoreGraphics

public enum JCSAPlacement {
	case leading
	case center
	case trailing
}

public enum JCSAxis: Int, Sendable, Codable, CustomStringConvertible {
	case horizontal
	case vertical

	public var description: String {
		switch self {
		case .horizontal: "horizontal"
		case .vertical: "vertical"
		}
	}
}
