import CoreGraphics

//TODO: Feature - JCSStack
public struct JCSStack: JCSDrawable {
	public let horzSize: JCSSize
	public let vertSize: JCSSize
	public let insets: JCSInsets
	public let align: JCSAlign
	public let content: [any JCSDrawable]

	public init(
		horzSize: JCSSize = .intrinsic(),
		vertSize: JCSSize = .intrinsic(),
		insets: JCSInsets = .init(),
		align: JCSAlign = .center,
		@JCSDrawableBuilder content: ()->[any JCSDrawable]
	) {
		self.horzSize = horzSize
		self.vertSize = vertSize
		self.insets = insets
		self.align = align
		self.content = content()
	}

	public init(
		horzSize: JCSSize = .intrinsic(),
		vertSize: JCSSize = .intrinsic(),
		insets: JCSInsets = .init(),
		align: JCSAlign = .center,
		content: [any JCSDrawable]
	) {
		self.horzSize = horzSize
		self.vertSize = vertSize
		self.insets = insets
		self.align = align
		self.content = content
	}

	public func measure(bounds: CGSize) -> CGSize {
		.zero
	}

	public func draw(in rect: CGRect, contentSize: CGSize, alignment: JCSAlign) {
	}
}
