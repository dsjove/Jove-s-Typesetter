import CoreGraphics

public struct Panel<C: JCSLayoutElement>: JCSLayoutElement {
	let insets: Insets
	//TODO: Aspect
	//TODO: min/max sizes
	let background: JCSRect
	let content: C?

	public init(
		insets: Insets = .init(),
		background: JCSRect = .init(),
		@JCSLayoutElementOptionalBuilder
		content: ()->C?
	) {
		self.init(insets: insets, background: background, content: content())
	}

	public init(
		insets: Insets = .init(),
		background: JCSRect = .init(),
		content: C?
	) {
		self.content = content
		self.insets = insets
		self.background = background
	}
	
	public func measure(bounds: CGSize) -> CGSize {
		if let content {
			let inset = insets.apply(size: bounds)
			let size = content.measure(bounds: inset)
			let outset = insets.apply(size: size, inverse: true)
			return outset
		}
		return .zero
	}

	public func draw(in allocated: CGRect, measured: CGSize, align: Alignment) {
		if let content {
			background.draw(in: allocated)
			let positioned = insets.apply(rect: allocated)
			let contentMeasured = insets.apply(size: measured)
			content.draw(in: positioned, measured: contentMeasured, align: align)
		}
	}
}
