import Foundation
import CoreGraphics

public protocol Pagination: AnyObject {
	var size: PageSize { get }
	var margin: CGSize { get }
	var landscape: Bool { get }

	var conceptName: String { get set }

	func beginPage()
	var number: Int { get }
	var cursor: CGFloat { get }
}

public extension Pagination {
	var pageRect: CGRect { size.rect(landscape: landscape, margin: .zero) }
	var drawRect: CGRect { size.rect(landscape: landscape, margin: margin) }
}

public class BasicPagination: Pagination {
//TODO: allow for cutom PageSize, here being (max, max)
	public let size: PageSize
	public let margin: CGSize
	public let landscape: Bool
	public private(set) var cursor: CGFloat
	public private(set) var number: Int
	public var conceptName: String

	public init(
		size: PageSize = PageSize.letter,
		margin: CGSize = CGSize(width: 18.0, height: 18.0),
		landscape: Bool = false,
		conceptName: String? = nil,
	) {
		self.size = size
		self.margin = margin
		self.landscape = landscape
		self.cursor = 0.0
		self.number = 0
		self.conceptName = conceptName ?? "Page 0"
	}

	public func beginPage() {
		self.cursor = 0.0
		self.number += 1
		self.conceptName = "Page \(number)"
	}
}
