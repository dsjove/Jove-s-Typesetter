import CoreGraphics

public extension CGFloat {
	static let unbounded: CGFloat = CGFloat.greatestFiniteMagnitude

	var isUnbounded: Bool {
		self == .unbounded
	}

	var unboundedDescription: String {
		isUnbounded ? "∞" : "\(self)"
	}
}

public extension CGSize {
	static let unbounded: CGSize = .init(width: CGFloat.unbounded, height: CGFloat.unbounded)

	init(fixedWidth: CGFloat) {
		self.init(width: fixedWidth, height: CGFloat.unbounded)
	}

	init(textHeight: CGFloat) {
		self.init(width: CGFloat.unbounded, height: textHeight)
	}

	var unboundedDescription: String {
		"(\(width.unboundedDescription)x\(height.unboundedDescription))"
	}

	func inset(by inset: CGFloat) -> CGSize {
		.init(width: width - inset*2, height: height - inset*2)
	}

	func inset(dx: CGFloat, dy: CGFloat) -> CGSize {
		.init(width: width - dx*2, height: height - dy*2)
	}
}

public extension CGRect {
	init(x: CGFloat, y: CGFloat, size: CGSize) {
		self.init(x: x, y: y, width: size.width, height: size.height)
	}
}
