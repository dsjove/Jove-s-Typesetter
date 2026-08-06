import CoreGraphics
import UIKit

public enum ImageSource: Sendable {
	case none
	case bundled(String, Bundle? = nil)
	case system(String)

	public var isEmpty: Bool {
		switch self {
		case .none:
			true
		case .bundled(let name, _):
			name.isEmpty
		case .system(let name):
			name.isEmpty
		}
	}

	public var image: UIImage? {
		switch self {
		case .none:
			nil
		case .bundled(let name, let bundle):
			UIImage(named: name, in: bundle, compatibleWith: nil)
		case .system(let name):
			UIImage(systemName: name)
		}
	}
}
