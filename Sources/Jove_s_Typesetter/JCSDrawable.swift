import CoreGraphics

/* Pagination
	will require a Drawable Group (keep together)
	and a 'y' cursor in context
*/

//TODO: Add Pagination, JCSAlign, JCSAspect, JCSInsets to the rendering chain
public protocol JCSDrawable {
	func measure(bounds: CGSize) -> CGSize

	//Rect with unbounded size is undefined
	func draw(in rect: CGRect)

	var page: Pagination { get }
}

nonisolated(unsafe) internal var drawablePage: Pagination = BasicPagination()

public extension JCSDrawable {
	func measure() -> CGSize {
		measure(bounds: .unbounded)
	}

	@discardableResult
	func draw(at origin: CGPoint, bounds: CGSize = .unbounded) -> CGRect {
		let rect = CGRect(origin: origin, size: measure(bounds: bounds))
		draw(in: rect)
		return rect
	}

	var page: Pagination {
		drawablePage
	}
}

public struct JCSEmptyDrawable: JCSDrawable {
	public func measure(bounds: CGSize) -> CGSize { .zero }
	public func draw(in rect: CGRect) {}

	public init() {}
}

@resultBuilder
public struct JCSDrawableBuilder {
	public typealias Component = [any JCSDrawable]

	public static func buildExpression<T: JCSDrawable>(
		_ expression: T
	) -> Component {
		[expression]
	}

	public static func buildExpression(
		_ expression: Component
	) -> Component {
		expression
	}

	public static func buildExpression<T: JCSDrawable>(
		_ expression: [T]
	) -> Component {
		expression.map { $0 as any JCSDrawable }
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
