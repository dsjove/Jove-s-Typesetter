import Foundation
import CoreGraphics

public protocol Pagination: AnyObject {
	var size: PageSize { get }
	var margin: CGSize { get }
	var landscape: Bool { get }
	var contentRect: CGRect { get }

	var conceptName: String { get set }

	func beginPage()
	var number: Int { get }
	var blockCursor: CGFloat { get }
}

public extension Pagination {
	var pageRect: CGRect { size.rect(landscape: landscape, margin: .zero) }
	var printableRect: CGRect { size.rect(landscape: landscape, margin: margin) }

	//TODO: Feature - Pagination
	// During drawing (not measuring) we need to be able to track this.
	// blockCursor is not an 'every item' draw
	// but a Drawable needs to be smart enough to know when (not) to call it
	// we also need a 'first draw always begins' check
	func request(height: CGFloat) {
		if blockCursor + height > printableRect.maxY {
			beginPage()
		}
	}
}

public class BasicPagination: Pagination {
	public let size: PageSize
	public let margin: CGSize
	public let landscape: Bool
	public let paging: ((Pagination) -> CGRect?)?
	public private(set) var blockCursor: CGFloat
	public private(set) var number: Int
	public var conceptName: String
	public private(set) var contentRect: CGRect

	public init(
		size: PageSize = PageSize.letter,
		margin: CGSize = CGSize(width: 18.0, height: 18.0),
		landscape: Bool = false,
		paging: ((Pagination) -> CGRect?)? = nil
	) {
		self.size = size
		self.margin = margin
		self.landscape = landscape
		self.paging = paging
		self.blockCursor = 0.0
		self.number = 0
		self.conceptName = "Page 0"
		self.contentRect = .zero
	}

	public func beginPage() {
		self.blockCursor = 0.0
		self.number += 1
		self.conceptName = "Page \(number)"
		self.contentRect = paging?(self) ?? printableRect
	}
}
