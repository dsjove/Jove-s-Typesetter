import CoreGraphics

public protocol JCSLayoutElement: TrackElement {
	// allocated and contentSize with unbounded values is undefined
	func draw(in allocated: CGRect, measured: CGSize, align: Alignment)

	var page: Pagination { get }
}

nonisolated(unsafe) internal var layoutElementPage: Pagination = BasicPagination()

public extension JCSLayoutElement {
	func measure() -> CGSize {
		measure(bounds: .unbounded)
	}

	// Does not measure, uses alloacted size if no measurement supplied
	func draw(in allocated: CGRect, measured: CGSize? = nil, align: Alignment = .leftTop) {
		draw(in: allocated, measured: measured ?? allocated.size, align: align)
	}

	// Auto measures, draws at origin, and returns allocated rect at origin
	@discardableResult
	func draw(at origin: CGPoint, bounds: CGSize = .unbounded, align: Alignment = .leftTop) -> CGRect {
		let measured = measure(bounds: bounds)
		let allocated = CGRect(origin: origin, size: measured)
		draw(in: allocated, measured: measured, align: align)
		return allocated
	}

	var page: Pagination {
		layoutElementPage
	}
}

public struct JCSEmptyDrawable: JCSLayoutElement {
	public func measure(bounds: CGSize) -> CGSize { .zero }
	public func draw(in allocated: CGRect, measured: CGSize, align: Alignment) {}

	public init() {}
}

public typealias JCSLayoutElements = [any JCSLayoutElement]

@resultBuilder
public struct JCSLayoutElementBuilder {
	public typealias Component = JCSLayoutElements

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
