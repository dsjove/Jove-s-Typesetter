import CoreGraphics

public protocol TrackElement {
	// required content size, do not return unbounded values
	func measure(bounds: CGSize) -> CGSize
}

public struct TrackedElement: TrackElement {
	public let element: any JCSLayoutElement

	public init(_ element: any JCSLayoutElement) {
		self.element = element
	}

	// see TrackElement
	public func measure(bounds: CGSize) -> CGSize {
		element.measure(bounds: bounds)
	}
}
