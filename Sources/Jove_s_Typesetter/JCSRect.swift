import CoreGraphics
import UIKit

//TODO: this is more of a drawing trait than an entity
public struct JCSRect {
	public let fill: UIColor
	public let stroke: UIColor
	public let lineWidth: CGFloat
	public let radius: CGFloat

	public init(
		fill: UIColor = .clear,
		stroke: UIColor = .clear,
		lineWidth: CGFloat = 1.0,
		radius: CGFloat = 0.0
	) {
		self.fill = fill
		self.stroke = stroke
		self.lineWidth = lineWidth
		self.radius = radius
	}

	@discardableResult
	public func draw(in rect: CGRect) -> CGRect {
		fill.setFill()
		stroke.setStroke()
		let path = UIBezierPath(borderRect: rect, cornerRadius: radius)
		path.fill()
		path.stroke()
		return rect
	}

	@discardableResult
	public func draw(center: CGPoint) -> CGRect {
		fill.setFill()
		stroke.setStroke()
		let rect = CGRect(
				x: center.x - radius,
				y: center.y - radius,
				width: radius * 2,
				height: radius * 2
			)
		let path = UIBezierPath(ovalIn: rect)
		path.fill()
		path.stroke()
		return rect
	}
}
