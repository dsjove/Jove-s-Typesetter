import Foundation
import CoreGraphics

public protocol Pagination	{
	var size: PageSize { get }
	var margin: CGSize { get }
	var landscape: Bool { get }

	func beginPage()
	var number: Int { get }
	var cursor: CGFloat { get }
}

public extension Pagination {
	var pageRect: CGRect { size.rect(landscape: landscape, margin: .zero) }
	var drawRect: CGRect { size.rect(landscape: landscape, margin: margin) }
}

public class BasicPagination: Pagination {
	public let size: PageSize
	public let margin: CGSize
	public let landscape: Bool
	public private(set) var cursor: CGFloat
	public private(set) var number: Int

	public init(
		size: PageSize = PageSize.letter,
		margin: CGSize = CGSize(width: 18.0, height: 18.0),
		landscape: Bool = false
	) {
		self.size = size
		self.margin = margin
		self.landscape = landscape
		self.cursor = 0.0
		self.number = 0
	}

	public func beginPage() {
		self.cursor = 0.0
		self.number += 1
	}
}
