import CoreGraphics

public struct JCSAlign: OptionSet, Sendable, Codable, CustomStringConvertible, CustomDebugStringConvertible {
	public let rawValue: Int
	public init(rawValue: Int) { self.rawValue = rawValue }

	public static let left   = JCSAlign(rawValue: 1 << 0) //1
	public static let right  = JCSAlign(rawValue: 1 << 1) //2
	public static let top    = JCSAlign(rawValue: 1 << 2) //4
	public static let bottom = JCSAlign(rawValue: 1 << 3) //8

	public static let centerX: JCSAlign = [.left, .right]
	public static let centerY: JCSAlign = [.top, .bottom]

	public static let leftTop: JCSAlign    = [.left, .top]
	public static let leftCenter: JCSAlign = [.left, .centerY]
	public static let leftBottom: JCSAlign = [.left, .bottom]

	public static let centerTop: JCSAlign    = [.centerX, .top]
	public static let center: JCSAlign       = [.centerX, .centerY]
	public static let centerBottom: JCSAlign = [.centerX, .bottom]

	public static let rightTop: JCSAlign    = [.right, .top]
	public static let rightCenter: JCSAlign = [.right, .centerY]
	public static let rightBottom: JCSAlign = [.right, .bottom]

	public func apply(size: CGSize, in rect: CGRect) -> CGRect {
		let x: CGFloat
		if contains(.centerX) {
			x = rect.minX + (rect.width - size.width) * 0.5
		} else if contains(.right) {
			x = rect.maxX - size.width
		} else {
			x = rect.minX
		}
		let y: CGFloat
		if contains(.centerY) {
			y = rect.minY + (rect.height - size.height) * 0.5
		} else if contains(.bottom) {
			y = rect.maxY - size.height
		} else {
			y = rect.minY
		}
		return .init(x: x, y: y, size: size)
	}

	public var description: String {
		if contains(.center) {
			return "Centered"
		}
		let x: String
		if contains(.centerX) {
			x = "Center"
		} else if contains(.right) {
			x = "Right"
		} else {
			x = "Left"
		}
		let y: String
		if contains(.centerY) {
			y = "Center"
		} else if contains(.bottom) {
			y = "Bottom"
		} else {
			y = "Top"
		}
		return "\(x)\(y)"
	}

	public var debugDescription: String {
		"\(description)\(rawValue)"
	}
}
