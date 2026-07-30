import CoreGraphics

public protocol JCSLayoutElement {
	// required content size, do not return unbounded values
	func measure(bounds: CGSize) -> CGSize

	//rect and contentSize with unbounded values is undefined
	func draw(in allocated: CGRect, measured: CGSize, align: JCSAlignment)

	var page: Pagination { get }
}

nonisolated(unsafe) internal var layoutElementPage: Pagination = BasicPagination()

public extension JCSLayoutElement {
	func measure() -> CGSize {
		measure(bounds: .unbounded)
	}

	func draw(in allocated: CGRect, measured: CGSize? = nil, align: JCSAlignment = .leftTop) {
		draw(in: allocated, measured: measured ?? allocated.size, align: align)
	}

	@discardableResult
	func draw(at origin: CGPoint, bounds: CGSize = .unbounded) -> CGRect {
		let measured = measure(bounds: bounds)
		let allocated = CGRect(origin: origin, size: measured)
		draw(in: allocated, measured: measured)
		return allocated
	}

	var page: Pagination {
		layoutElementPage
	}
}

public struct JCSEmptyDrawable: JCSLayoutElement {
	public func measure(bounds: CGSize) -> CGSize { .zero }
	public func draw(in allocated: CGRect, measured: CGSize, align: JCSAlignment) {}

	public init() {}
}

@resultBuilder
public struct JCSLayoutElementBuilder {
	public typealias Component = [any JCSLayoutElement]

	public static func buildExpression<T: JCSLayoutElement>(
		_ expression: T
	) -> Component {
		[expression]
	}

	public static func buildExpression(
		_ expression: Component
	) -> Component {
		expression
	}

	public static func buildExpression<T: JCSLayoutElement>(
		_ expression: [T]
	) -> Component {
		expression.map { $0 as any JCSLayoutElement }
	}
	public static func buildBlock(
		_ components: Component...
	) -> Component {
		components.flatMap { $0 }
	}

	public static func buildOptional(
		_ component: Component?
	) -> Component {
		component ?? []
	}

	public static func buildEither(
		first component: Component
	) -> Component {
		component
	}

	public static func buildEither(
		second component: Component
	) -> Component {
		component
	}

	public static func buildArray(
		_ components: [Component]
	) -> Component {
		components.flatMap { $0 }
	}
}
