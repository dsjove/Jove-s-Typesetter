import Foundation
import UIKit

public extension UIBezierPath {
	convenience init(borderRect rect: CGRect, cornerRadius: CGFloat?) {
		if let cornerRadius, cornerRadius > 0.0 {
			self.init(roundedRect: rect, cornerRadius: cornerRadius)
		} else {
			self.init(rect: rect)
		}
	}
}

// NSAttributedString has no notion of vertical alignment
public extension JCSAlign {
	init(_ textAlignment: NSTextAlignment) {
		switch (textAlignment) {
			case .left:  self = .leftTop
			case .right: self = .rightTop
			default:     self = .centerTop
		}
	}

	var textAlignment: NSTextAlignment {
		if contains(.centerX) { return .center }
		if contains(.right)  { return .right }
		return .left
	}
}
