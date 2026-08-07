import SwiftUI
import PDFKit

public struct PDFKitView: UIViewRepresentable {
    public enum Command: Equatable {
        case firstPage
        case lastPage
    }

    public let document: PDFDocument
    @Binding private var command: Command?

    public init(document: PDFDocument, command: Binding<Command?> = .constant(nil)) {
        self.document = document
        self._command = command
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    public final class Coordinator {
        fileprivate init() {}
		@MainActor fileprivate func perform(_ command: Command, on view: PDFView) {
            switch command {
            case .firstPage:
                view.goToFirstPage(nil)
            case .lastPage:
                view.goToLastPage(nil)
            }
        }
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
        if let cmd = command {
            context.coordinator.perform(cmd, on: view)
            // Reset command after handling so a future identical command can be triggered again
            DispatchQueue.main.async {
                self._command.wrappedValue = nil
            }
        }
    }
}
