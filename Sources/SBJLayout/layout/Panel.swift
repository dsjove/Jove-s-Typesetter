import CoreGraphics

public struct Panel<C: JCSLayoutElement>: JCSLayoutElement {
	let insets: Insets
	let align: Alignment
	//TODO: Aspect
	//TODO: min/max sizes
	let background: JCSRect
	let content: JCSLayoutElement

	public init(
		insets: Insets = .init(),
		align: Alignment = .center,
		background: JCSRect = .init(),
		content: ()->C
	) {
		self.init(insets: insets, align: align, background: background, content: content())
	}

	public init(
		insets: Insets = .init(),
		align: Alignment = .center,
		background: JCSRect = .init(),
		content: C
	) {
		self.content = content
		self.insets = insets
		self.background = background
		self.align = align
	}
	
	public func measure(bounds: CGSize) -> CGSize {
		let inset = insets.apply(size: bounds)
		let size = content.measure(bounds: inset)
		let outset = insets.apply(size: size, inverse: true)
		return outset
	}

	public func draw(in allocated: CGRect, measured: CGSize, align: Alignment) {
		background.draw(in: allocated)
		let contentSize = insets.apply(size: allocated.size)
		let positioned = align.apply(size: contentSize, in: allocated)
		content.draw(in: positioned, measured: measured, align: align)
	}
}
