import CoreGraphics

public struct JCSFlow: JCSDrawable {
// TODO: Feature - pagination

// Lines
	public struct LineRendering {
		public let def: Definition
		public let line: LineDef
		public let l: Int
		public let rect: CGRect
	}

	public struct LineDef {
		public let gap: CGFloat
		public let alignment: JCSAlign
		public let render: ((LineRendering) -> ())?

		public init(
			gap: CGFloat = 2.0,
			alignment: JCSAlign = .leftTop,
			render: ((LineRendering) -> ())? = nil
		) {
			self.gap = gap
			self.alignment = alignment
			self.render = render
		}
	}

	public struct Lines {
		public let def: (Int) -> LineDef

		public init(def: @escaping (Int) -> LineDef) {
			self.def = def
		}
	}

// Items
	public struct ItemRendering {
		public let def: Definition
		public let item: ItemDef
		public let l: Int
		public let i: Int
		public let rect: CGRect

		public func render() {
			def.item(at: i)?.draw(in: rect)
		}
	}

	public struct ItemDef {
		public let width: JCSSize
		public let height: JCSSize
		public let gap: CGFloat
		public let alignment: JCSAlign
		public let render: ((ItemRendering) -> ())?

		public init(
			width: JCSSize = .intrinsic(),
			height: JCSSize = .intrinsic(),
			gap: CGFloat = 2.0,
			alignment: JCSAlign = .leftTop,
			render: ((ItemRendering) -> ())? = nil
		) {
			self.width = width
			self.height = height
			self.gap = gap
			self.alignment = alignment
			self.render = render
		}
	}

	public typealias Item = any JCSDrawable

	public struct Items {
		public var count: Int { content.count }

		public let content: [Item]
		public let def: (Int) -> ItemDef

		public init(
			content: [Item],
			def: @escaping (Int) -> ItemDef
		) {
			self.content = content
			self.def = def
		}

		public func item(at i: Int) -> JCSDrawable? {
			i >= 0 && i < count ? content[i] : nil
		}
	}

// Definition
	public struct Definition {
		public let dbgName: String
		public let direction: Direction
		public let contentAlignment: JCSAlign
		public let lines: Lines
		public let items: Items

		public var isEmpty: Bool { itemCount == 0 }
		public var itemCount: Int { items.count }

		public init(
			dbgName: String,
			direction: Direction,
			contentAlignment: JCSAlign = .leftTop,
			lines: Lines,
			items: Items
		) {
			self.dbgName = dbgName
			self.direction = direction
			self.contentAlignment = contentAlignment
			self.lines = lines
			self.items = items
		}

		public func item(at i: Int) -> JCSDrawable? {
			items.item(at: i)
		}
	}

	public let def: Definition

	private let preparedLayout: PreparedLayout

	// Item sorting should happen outside the Flow.
	// This is not a reactive flow where lines/items have identity.
	public init(
		dbgName: String = "",
		direction: Direction = .horizontal,
		contentAlignment: JCSAlign = .leftTop,
		_ lines: Lines,
		_ items: Items
	) {
		let def = Definition(
			dbgName: dbgName,
			direction: direction,
			contentAlignment: contentAlignment,
			lines: lines,
			items: items
		)
		self.def = def
		self.preparedLayout = Self.prepare(def)
	}

	private struct PreparedLayout {
		var measured: [CGSize] = []
		var itemSizes: [CGSize] = []
	}

	private struct LineLayout {
		let range: Range<Int>
		let rect: CGRect
	}

	private struct CalculatedLayout {
		var lines: [LineLayout] = []
		var itemRects: [CGRect] = []
		var occupiedSize: CGSize = .zero
		var size: CGSize = .zero
	}

	private static func prepare(_ def: Definition) -> PreparedLayout {
		guard !def.isEmpty else { return .init() }

		let itemCount = def.itemCount
		var measured = Array(repeating: CGSize.zero, count: itemCount)
		var itemSizes = Array(repeating: CGSize.zero, count: itemCount)

		for i in 0..<itemCount {
			guard let drawable = def.item(at: i) else { continue }
			let item = def.items.def(i)

			let bounds = CGSize(
				width: measurementBound(item.width),
				height: measurementBound(item.height)
			)
			measured[i] = drawable.measure(bounds: bounds)

			if case .intrinsic(_, let minWidth) = item.width,
			   let minWidth,
			   measured[i].width < minWidth {
				measured[i] = drawable.measure(
					bounds: CGSize(
						width: minWidth,
						height: bounds.height
					)
				)
				measured[i].width = minWidth
			}

			if case .intrinsic(_, let minHeight) = item.height,
			   let minHeight {
				measured[i].height = max(measured[i].height, minHeight)
			}
		}

		var uniformWidth: CGFloat = 0
		var uniformHeight: CGFloat = 0

		for i in 0..<itemCount {
			let item = def.items.def(i)
			if case .uniform = item.width {
				uniformWidth = max(uniformWidth, measured[i].width)
			}
			if case .uniform = item.height {
				uniformHeight = max(uniformHeight, measured[i].height)
			}
		}

		// A resolved uniform width can change measured height.
		if uniformWidth > 0 {
			for i in 0..<itemCount {
				let item = def.items.def(i)
				guard case .uniform = item.width,
					  let drawable = def.item(at: i) else {
					continue
				}

				measured[i] = drawable.measure(
					bounds: CGSize(
						width: uniformWidth,
						height: measurementBound(item.height)
					)
				)
			}

			uniformHeight = 0
			for i in 0..<itemCount {
				if case .uniform = def.items.def(i).height {
					uniformHeight = max(uniformHeight, measured[i].height)
				}
			}
		}

		for i in 0..<itemCount {
			let item = def.items.def(i)
			itemSizes[i] = CGSize(
				width: preparedDimension(
					item.width,
					measured: measured[i].width,
					uniform: uniformWidth
				),
				height: preparedDimension(
					item.height,
					measured: measured[i].height,
					uniform: uniformHeight
				)
			)
		}

		return .init(
			measured: measured,
			itemSizes: itemSizes
		)
	}

	private static func measurementBound(_ size: JCSSize) -> CGFloat {
		switch size {
		case .fixed(let value):
			return value
		case .intrinsic(let bound, _):
			return bound
		case .uniform, .fill:
			return .unbounded
		}
	}

	private static func preparedDimension(
		_ size: JCSSize,
		measured: CGFloat,
		uniform: CGFloat
	) -> CGFloat {
		switch size {
		case .fixed(let value):
			return max(value, 0)
		case .intrinsic:
			return max(measured, 0)
		case .uniform:
			return max(uniform, 0)
		case .fill:
			// Fill is resolved against a concrete line during layout.
			return 0
		}
	}

	private static func fillFraction(_ fraction: CGFloat?) -> CGFloat {
		max(fraction ?? 1.0, 0)
	}

	private func calculateLayout(bounds: CGSize) -> CalculatedLayout {
		guard !def.isEmpty else {
			return .init(size: measuredContainerSize(.zero, bounds))
		}

		switch def.direction {
		case .horizontal:
			return calculateHorizontalLayout(bounds: bounds)
		case .vertical:
			return calculateVerticalLayout(bounds: bounds)
		}
	}

	private func calculateHorizontalLayout(bounds: CGSize) -> CalculatedLayout {
		let itemCount = def.itemCount
		let wrapWidth = bounds.width

		var lines: [LineLayout] = []
		var itemRects = Array(repeating: CGRect.zero, count: itemCount)

		var lineStart = 0
		var x: CGFloat = 0
		var y: CGFloat = 0
		var previousGap: CGFloat = 0

		func appendLine(end: Int) {
			guard end > lineStart else { return }

			let lineIndex = lines.count
			let line = def.lines.def(lineIndex)
			let occupiedWidth = max(x, 0)

			var lineHeight: CGFloat = 0
			for i in lineStart..<end {
				let item = def.items.def(i)
				if case .fill = item.height { continue }
				lineHeight = max(lineHeight, itemRects[i].height)
			}

			// Cross-axis fill uses the final natural line height.
			for i in lineStart..<end {
				let item = def.items.def(i)
				if case .fill(let fraction) = item.height {
					itemRects[i].size.height = min(
						lineHeight * Self.fillFraction(fraction),
						lineHeight
					)
				}
			}

			let containerWidth = wrapWidth.isUnbounded
				? occupiedWidth
				: wrapWidth
			let primaryOffset = Self.horizontalOffset(
				alignment: line.alignment,
				available: containerWidth,
				occupied: occupiedWidth
			)

			for i in lineStart..<end {
				let item = def.items.def(i)
				let rect = itemRects[i]
				let crossOffset = Self.verticalOffset(
					alignment: item.alignment,
					available: lineHeight,
					occupied: rect.height
				)
				itemRects[i].origin.x += primaryOffset
				itemRects[i].origin.y += crossOffset
			}

			lines.append(
				.init(
					range: lineStart..<end,
					rect: CGRect(
						x: 0,
						y: y,
						width: containerWidth,
						height: lineHeight
					)
				)
			)

			y += lineHeight + line.gap
			lineStart = end
			x = 0
			previousGap = 0
		}

		for i in 0..<itemCount {
			let item = def.items.def(i)
			var itemSize = preparedLayout.itemSizes[i]

			var itemStart = x
			if x > 0 {
				itemStart += previousGap
			}

			if case .fill(let fraction) = item.width {
				if wrapWidth.isUnbounded {
					itemSize = .zero
				} else {
					if itemStart >= wrapWidth && lineStart < i {
						appendLine(end: i)
						itemStart = 0
					}

					let remaining = max(wrapWidth - itemStart, 0)
					itemSize.width = min(
						remaining * Self.fillFraction(fraction),
						remaining
					)

					if itemSize.width > 0,
					   let drawable = def.item(at: i) {
						let measured = drawable.measure(
							bounds: CGSize(
								width: itemSize.width,
								height: Self.measurementBound(item.height)
							)
						)
						itemSize.height = Self.resolvedCrossDimension(
							item.height,
							prepared: itemSize.height,
							measured: measured.height
						)
					}
				}
			} else if !wrapWidth.isUnbounded,
					  lineStart < i,
					  itemStart + itemSize.width > wrapWidth {
				appendLine(end: i)
				itemStart = 0
			}

			itemRects[i] = CGRect(x: itemStart, y: y, size: itemSize)

			if itemSize.width > 0 {
				x = itemStart + itemSize.width
				previousGap = item.gap
			}
		}

		appendLine(end: itemCount)

		if !lines.isEmpty {
			y -= def.lines.def(lines.count - 1).gap
		}

		let occupiedWidth = lines.reduce(CGFloat.zero) {
			max($0, $1.rect.width)
		}
		let occupiedSize = CGSize(
			width: wrapWidth.isUnbounded ? occupiedWidth : wrapWidth,
			height: max(y, 0)
		)

		return .init(
			lines: lines,
			itemRects: itemRects,
			occupiedSize: occupiedSize,
			size: measuredContainerSize(occupiedSize, bounds)
		)
	}

	private func calculateVerticalLayout(bounds: CGSize) -> CalculatedLayout {
		let itemCount = def.itemCount
		let wrapHeight = bounds.height

		var lines: [LineLayout] = []
		var itemRects = Array(repeating: CGRect.zero, count: itemCount)

		var lineStart = 0
		var x: CGFloat = 0
		var y: CGFloat = 0
		var previousGap: CGFloat = 0

		func appendLine(end: Int) {
			guard end > lineStart else { return }

			let lineIndex = lines.count
			let line = def.lines.def(lineIndex)
			let occupiedHeight = max(y, 0)

			var lineWidth: CGFloat = 0
			for i in lineStart..<end {
				let item = def.items.def(i)
				if case .fill = item.width { continue }
				lineWidth = max(lineWidth, itemRects[i].width)
			}

			// Cross-axis fill uses the final natural line width.
			for i in lineStart..<end {
				let item = def.items.def(i)
				if case .fill(let fraction) = item.width {
					itemRects[i].size.width = min(
						lineWidth * Self.fillFraction(fraction),
						lineWidth
					)
				}
			}

			let containerHeight = wrapHeight.isUnbounded
				? occupiedHeight
				: wrapHeight
			let primaryOffset = Self.verticalOffset(
				alignment: line.alignment,
				available: containerHeight,
				occupied: occupiedHeight
			)

			for i in lineStart..<end {
				let item = def.items.def(i)
				let rect = itemRects[i]
				let crossOffset = Self.horizontalOffset(
					alignment: item.alignment,
					available: lineWidth,
					occupied: rect.width
				)
				itemRects[i].origin.x += crossOffset
				itemRects[i].origin.y += primaryOffset
			}

			lines.append(
				.init(
					range: lineStart..<end,
					rect: CGRect(
						x: x,
						y: 0,
						width: lineWidth,
						height: containerHeight
					)
				)
			)

			x += lineWidth + line.gap
			lineStart = end
			y = 0
			previousGap = 0
		}

		for i in 0..<itemCount {
			let item = def.items.def(i)
			var itemSize = preparedLayout.itemSizes[i]

			var itemStart = y
			if y > 0 {
				itemStart += previousGap
			}

			if case .fill(let fraction) = item.height {
				if wrapHeight.isUnbounded {
					itemSize = .zero
				} else {
					if itemStart >= wrapHeight && lineStart < i {
						appendLine(end: i)
						itemStart = 0
					}

					let remaining = max(wrapHeight - itemStart, 0)
					itemSize.height = min(
						remaining * Self.fillFraction(fraction),
						remaining
					)

					if itemSize.height > 0,
					   let drawable = def.item(at: i) {
						let measured = drawable.measure(
							bounds: CGSize(
								width: Self.measurementBound(item.width),
								height: itemSize.height
							)
						)
						itemSize.width = Self.resolvedCrossDimension(
							item.width,
							prepared: itemSize.width,
							measured: measured.width
						)
					}
				}
			} else if !wrapHeight.isUnbounded,
					  lineStart < i,
					  itemStart + itemSize.height > wrapHeight {
				appendLine(end: i)
				itemStart = 0
			}

			itemRects[i] = CGRect(x: x, y: itemStart, size: itemSize)

			if itemSize.height > 0 {
				y = itemStart + itemSize.height
				previousGap = item.gap
			}
		}

		appendLine(end: itemCount)

		if !lines.isEmpty {
			x -= def.lines.def(lines.count - 1).gap
		}

		let occupiedHeight = lines.reduce(CGFloat.zero) {
			max($0, $1.rect.height)
		}
		let occupiedSize = CGSize(
			width: max(x, 0),
			height: wrapHeight.isUnbounded ? occupiedHeight : wrapHeight
		)

		return .init(
			lines: lines,
			itemRects: itemRects,
			occupiedSize: occupiedSize,
			size: measuredContainerSize(occupiedSize, bounds)
		)
	}

	private static func resolvedCrossDimension(
		_ size: JCSSize,
		prepared: CGFloat,
		measured: CGFloat
	) -> CGFloat {
		switch size {
		case .intrinsic:
			return max(measured, 0)
		case .fill:
			return 0
		case .fixed, .uniform:
			return prepared
		}
	}

	private func measuredContainerSize(
		_ occupiedSize: CGSize,
		_ bounds: CGSize
	) -> CGSize {
		switch def.direction {
		case .horizontal:
			return CGSize(
				width: bounds.width.isUnbounded
					? occupiedSize.width
					: bounds.width,
				height: occupiedSize.height
			)

		case .vertical:
			return CGSize(
				width: occupiedSize.width,
				height: bounds.height.isUnbounded
					? occupiedSize.height
					: bounds.height
			)
		}
	}

	private static func horizontalOffset(
		alignment: JCSAlign,
		available: CGFloat,
		occupied: CGFloat
	) -> CGFloat {
		if alignment.contains(.centerX) {
			return (available - occupied) * 0.5
		}
		if alignment.contains(.right) {
			return available - occupied
		}
		return 0
	}

	private static func verticalOffset(
		alignment: JCSAlign,
		available: CGFloat,
		occupied: CGFloat
	) -> CGFloat {
		if alignment.contains(.centerY) {
			return (available - occupied) * 0.5
		}
		if alignment.contains(.bottom) {
			return available - occupied
		}
		return 0
	}

// Drawable measure
	public func measure(bounds: CGSize) -> CGSize {
		calculateLayout(bounds: bounds).size
	}

// Drawable draw
	public func draw(in rect: CGRect, contentSize: CGSize, alignment: JCSAlign) {
		let calculated = calculateLayout(bounds: rect.size)
		let occupiedRect = def.contentAlignment.apply(
			size: calculated.occupiedSize,
			in: rect
		)
		let origin = occupiedRect.origin

		for (lineIndex, lineLayout) in calculated.lines.enumerated() {
			let absoluteLineRect = lineLayout.rect.offsetBy(
				dx: origin.x,
				dy: origin.y
			)

			if absoluteLineRect.minX > rect.maxX ||
			   absoluteLineRect.minY > rect.maxY {
				break
			}

			let line = def.lines.def(lineIndex)
			if let render = line.render {
				render(
					.init(
						def: def,
						line: line,
						l: lineIndex,
						rect: absoluteLineRect
					)
				)
			}

			for i in lineLayout.range {
				let absoluteItemRect = calculated.itemRects[i].offsetBy(
					dx: origin.x,
					dy: origin.y
				)

				if absoluteItemRect.minX > rect.maxX ||
				   absoluteItemRect.minY > rect.maxY {
					continue
				}

				let item = def.items.def(i)
				let rendering = ItemRendering(
					def: def,
					item: item,
					l: lineIndex,
					i: i,
					rect: absoluteItemRect
				)

				if let render = item.render {
					render(rendering)
				} else {
					rendering.render()
				}

				if !def.dbgName.isEmpty {
					JCSRect(
						fill: .clear,
						stroke: .red.withAlphaComponent(0.5),
						lineWidth: 0.5,
						radius: 0
					).draw(in: absoluteItemRect)
				}
			}
		}
	}
}
