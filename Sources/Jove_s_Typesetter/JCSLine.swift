import CoreGraphics
import UIKit

//TODO: see JCSRect comment
public struct JCSLine {
	public let stroke: UIColor
	public let lineWidth: CGFloat

	public init(stroke: UIColor, lineWidth: CGFloat) {
		self.stroke = stroke
		self.lineWidth = lineWidth
	}

	@discardableResult
	public func draw(from: CGPoint, to: CGPoint) -> CGRect {
		stroke.setStroke()
		let path = UIBezierPath()
		path.move(to: from)
		path.addLine(to: to)
		path.lineWidth = lineWidth
		path.stroke()
		return CGRect(x: min(from.x, to.x), y: min(from.y, to.y), width: abs(from.x - to.x), height: abs(from.y - to.y))
	}
}
