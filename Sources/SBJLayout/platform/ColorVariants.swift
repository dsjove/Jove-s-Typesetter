import SwiftUI
import UIKit

public enum ColorVariants {
	case parts(Double, Double, Double, Double = 1.0)
	case uiKit(UIColor)
	case swiftUI(Color)
	case asset(String)
}

public extension CodableColor {
	init(color: ColorVariants) {
		switch color {
		case .parts(let r, let g, let b, let a):
			self = CodableColor(r, g, b, a)
		case .uiKit(let uiColor):
			self = .init(color: uiColor)
		case .swiftUI(let swiftUIColor):
			self = .init(color: swiftUIColor)
		case .asset(let name):
			self = .init(color: Color(name))
		}
	}
}
