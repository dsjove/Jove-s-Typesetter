import SwiftUI
import PDFKit

public struct PDFKitView: UIViewRepresentable {
	public let document: PDFDocument

	public init(document: PDFDocument) {
		self.document = document
	}

	public func makeUIView(context: Context) -> PDFView {
		let view = PDFView()
		view.autoScales = true
		view.displayMode = .singlePageContinuous
		view.displayDirection = .vertical
		view.displaysPageBreaks = true
		view.backgroundColor = .secondarySystemBackground
		view.document = document
		return view
	}

	public func updateUIView(_ view: PDFView, context: Context) {
		if view.document !== document {
			view.document = document
		}
	}
}
