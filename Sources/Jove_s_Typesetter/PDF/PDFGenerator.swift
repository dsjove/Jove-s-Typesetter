import Foundation
import PDFKit

public struct PDFGenerator {
	public let pageSize: PageSize
	public let margin: CGSize
	public let landscape: Bool

	public init(
		pageSize: PageSize = PageSize.letter,
		margin: CGSize = CGSize(width: 18.0, height: 18.0),
		landscape: Bool = false
	) {
		self.pageSize = pageSize
		self.margin = margin
		self.landscape = landscape
	}

	public func render(_ content: JCSLayoutElement, _ paging: ((Pagination) -> CGRect?)? = nil) -> Data {
		let pageRect = pageSize.rect(landscape: landscape, margin: .zero)
		let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
		return renderer.pdfData { context in
			let page = BasicPagination(size: pageSize, margin: margin, landscape: landscape) {
				context.beginPage()
				return paging?($0)
			}
			layoutElementPage = page
			//TODO: Not measured?
			content.draw(in: page.contentRect)
		}
	}

	public func form(_ content: JCSLayoutElement, _ paging: ((Pagination) -> CGRect?)? = nil) -> (Data, PDFDocument?) {
		let pdfData: Data = render(content, paging)
		return (pdfData, PDFDocument(data: pdfData))
	}
}
