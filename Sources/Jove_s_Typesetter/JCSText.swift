import CoreGraphics
import UIKit

public struct JCSText: JCSLayoutElement {
	public let text: String?
	public let font: UIFont
	public let color: UIColor
	public let minLines: Int
	public let maxLines: Int
	public let content: NSMutableAttributedString?
// TODO: Bug - do copy-on-write for content member and cache measurement

	public init(
		_ text: String?,
		font: UIFont = UIFont.systemFont(ofSize: 9.0),
		color: UIColor = UIColor.black,
		lines: Int
	) {
		self.init(text, font: font, color: color, minLines: lines, maxLines: lines)
	}

	public init(
		_ text: String?,
		font: UIFont = UIFont.systemFont(ofSize: 9.0),
		color: UIColor = UIColor.black,
		minLines: Int = 0,
		maxLines: Int = Int.max
	) {
		self.text = text
		self.font = font
		self.color = color
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

	public func draw(in allocated: CGRect, measured: CGSize, align: JCSAlignment) {
		guard let content else { return }
		var r = allocated
		//NSAttributedString has alignment built into the attributes
		content.addAttribute(
			.paragraphStyle,
			value: {
				let paragraphStyle = NSMutableParagraphStyle()
				paragraphStyle.alignment = align.textAlignment
				paragraphStyle.lineBreakMode = .byWordWrapping
				return paragraphStyle
			}(),
			range: NSRange(
				location: 0,
				length: content.length
			)
		)
		//NSAttributedString has no notion of vertical alignment
		if align.contains(.bottom) {
			let size = measure(bounds: allocated.size)
			r = align.apply(size: size, in: allocated).integral
		}
		content.draw(with: r, options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
	}
}
