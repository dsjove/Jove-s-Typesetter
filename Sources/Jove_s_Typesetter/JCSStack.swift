import CoreGraphics

//TODO: Feature - JCSStack
public struct JCSStack: JCSLayoutElement {
	public let width: JCSDimension
	public let height: JCSDimension
	public let insets: JCSInsets
	public let align: JCSAlignment
	public let content: [any JCSLayoutElement]

	public init(
		width: JCSDimension = .intrinsic(),
		height: JCSDimension = .intrinsic(),
		insets: JCSInsets = .init(),
		align: JCSAlignment = .center,
		@JCSLayoutElementBuilder content: ()->[any JCSLayoutElement]
	) {
		self.width = width
		self.height = height
		self.insets = insets
		self.align = align
		self.content = content()
	}

	public init(
		width: JCSDimension = .intrinsic(),
		height: JCSDimension = .intrinsic(),
		insets: JCSInsets = .init(),
		align: JCSAlignment = .center,
		content: [any JCSLayoutElement]
	) {
		self.width = width
		self.height = height
		self.insets = insets
		self.align = align
		self.content = content
	}

	public func measure(bounds: CGSize) -> CGSize {
		.zero
	}

	public func draw(in allocated: CGRect, measured: CGSize, align: JCSAlignment) {
	}
}
