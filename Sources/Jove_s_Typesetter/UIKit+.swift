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
