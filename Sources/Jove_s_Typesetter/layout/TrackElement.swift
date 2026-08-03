import CoreGraphics

public protocol TrackElement {
	// required content size, do not return unbounded values
	func measure(bounds: CGSize) -> CGSize
}
