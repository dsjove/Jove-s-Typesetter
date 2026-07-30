import Foundation
import PDFKit

public class PDFPagination: BasicPagination {
	public let context: UIGraphicsPDFRendererContext

	public init(
		_ context: UIGraphicsPDFRendererContext,
		_ size: PageSize = PageSize.letter,
		_ margin: CGSize = CGSize(width: 18.0, height: 18.0),
		_ landscape: Bool = false
	) {
		self.context = context
		super.init(size: size, margin: margin, landscape: landscape)
		drawablePage = self
	}

	public override func  beginPage() {
		super.beginPage()
		context.beginPage()
	}
}

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

	public func render(_ drawable: JCSLayoutElement) -> Data {
		let pageRect = pageSize.rect(landscape: landscape, margin: .zero)
		let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
		return renderer.pdfData { context in
			let page = PDFPagination(context, pageSize, margin, landscape)
			//Not measured
			drawable.draw(in: page.contentRect)
		}
	}

	public func form(_ drawable: JCSLayoutElement) -> (Data, PDFDocument?) {
		let pdfData: Data = render(drawable)
		return (pdfData, PDFDocument(data: pdfData))
	}
}
