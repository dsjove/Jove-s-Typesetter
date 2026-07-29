import CoreGraphics

//TODO: cleanup, make drawable, handle empty elements, allow for circle
public struct JCSCheckBox {
	public let box: JCSRect
	public let boxSize: CGFloat
	public let labelGap: CGFloat
	public let text: JCSText

	public init(box: JCSRect, boxSize: CGFloat, labelGap: CGFloat, text: JCSText) {
		self.box = box
		self.boxSize = boxSize
		self.labelGap = labelGap
		self.text = text
	}

	@discardableResult
	public func draw(at point: CGPoint) -> CGRect {
		let boxRect = CGRect(x: point.x, y: point.y, width: boxSize, height: boxSize)
		box.draw(in: boxRect)
		return boxRect
	}

	public func draw2(at point: CGPoint, maxWidth: CGFloat = .greatestFiniteMagnitude) -> CGRect {
		let boxRect = CGRect(x: point.x, y: point.y, width: boxSize, height: boxSize)
		box.draw(in: boxRect)
		let textSize = text.measure(bounds: CGSize(fixedWidth: maxWidth - boxSize - labelGap))
		let textRect = CGRect(
			x: boxRect.maxX + labelGap,
			y: boxRect.midY - textSize.height / 2,
			width: textSize.width,
			height: textSize.height)
		text.draw2(at: textRect.origin)
		return boxRect.union(textRect)
	}
}
