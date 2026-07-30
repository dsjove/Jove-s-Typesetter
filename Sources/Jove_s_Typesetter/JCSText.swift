import CoreGraphics
import UIKit

public struct JCSText: JCSDrawable {
	public let text: String?
	public let color: UIColor
	public let font: UIFont
	public let minLines: Int
	public let maxLines: Int
	public let content: NSMutableAttributedString?

	public init(
		text: String?,
		color: UIColor = UIColor.black,
		font: UIFont = UIFont.systemFont(ofSize: 9.0),
		minLines: Int = 0,
		maxLines: Int = Int.max
	) {
		self.text = text
		self.color = color
		self.font = font
		self.minLines = minLines
		self.maxLines = maxLines

		if let text, !text.isEmpty {
			content = NSMutableAttributedString(string: text, attributes: [
				.font: font,
				.foregroundColor: color,
			])
		}
		else {
			content = nil
		}
	}
	
	public func measure(bounds: CGSize = .unbounded) -> CGSize {
		guard let content else {
			return CGSize(
				width: 0.0,
				height: ceil(CGFloat(minLines) * font.lineHeight))
		}
		var measured = content.boundingRect(
			with: bounds,
			options: [.usesLineFragmentOrigin, .usesFontLeading],
			context: nil
		).integral.size

		if bounds.width != .unbounded {
			measured.width = ceil(bounds.width)
		}
		if minLines > 1 {
			let minHeight = ceil(CGFloat(minLines) * font.lineHeight)
			measured.height = max(minHeight, measured.height)
		}
		if maxLines > 0 && maxLines != Int.max {
			let maxHeight = ceil(CGFloat(maxLines) * font.lineHeight)
			measured.height = min(maxHeight, measured.height)
		}
		return measured
	}

	public func draw(in rect: CGRect, contentSize: CGSize, alignment: JCSAlign) {
		guard let content else { return }
		var r = rect

		//NSAttributedString has alignment built in
		let paragraphStyle = NSMutableParagraphStyle()
		paragraphStyle.alignment = alignment.textAlignment
		content.addAttribute(
			.paragraphStyle,
			value: paragraphStyle,
			range: NSRange(
				location: 0,
				length: content.length
			)
		)
		//NSAttributedString has no notion of vertical alignment
		if alignment.contains(.bottom) {
			let size = measure(bounds: rect.size)
			r = alignment.apply(size: size, in: rect).integral
		}
		content.draw(with: r, options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
	}
}
