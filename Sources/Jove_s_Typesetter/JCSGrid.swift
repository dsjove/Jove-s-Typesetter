import CoreGraphics

public struct JCSGrid: JCSDrawable {
// TODO: Feature - Pagination
// TODO: Feature - Pivot Table
// TODO: Bug - for rows and columns, if there are several zero-sized elements at the end, we will have an extra gap
// TODO: Feature - Wrapping 'wrapping: Direction?'
//     hits bottom, sets y = 0 and x+=width, measured width needs to account
//     hits right, sets x = 0 and y+=height, measured height needs to account

// Columns
	public struct ColumnRendering {
		public let def: Definition
		public let c: Int
		public let rect: CGRect
	}
	public struct ColumnDef {
		public let width: JCSSize
		public let align: JCSAlign
		public let gap: CGFloat
		public let render: ((ColumnRendering)->())?

		public init(
			width: JCSSize = .intrinsic(),
			align: JCSAlign = .left,
			gap: CGFloat = 2.0,
			render: ((ColumnRendering) -> ())? = nil
		) {
			self.width = width
			self.align = align
			self.gap = gap
			self.render = render
		}
	}
	public typealias Columns = [ColumnDef]

// Rows
	public struct RowRendering {
		public let def: Definition
		public let row: RowDef
		public let r: Int
		public let rect: CGRect
	}
	public struct RowDef {
		public let height: JCSSize
		public let align: JCSAlign
		public let gap: CGFloat
		public let render: ((RowRendering)->())?

		public init(
			height: JCSSize = .intrinsic(),
			align: JCSAlign = .top,
			gap: CGFloat = 2.0,
			render: ((RowRendering) -> ())? = nil
		) {
			self.height = height
			self.align = align
			self.gap = gap
			self.render = render
		}
	}
	public struct Rows {
		let min: Int
		let max: Int
		let def: (Int)->RowDef

		public init(
			min: Int = 0,
			max: Int = Int.max,
			def: @escaping (Int) -> RowDef = {_ in .init() }
		) {
			self.min = min
			self.max = max
			self.def = def
		}
	}

// Cells
	public struct CellRendering {
		public let def: Definition
		public let c: Int
		public let r: Int
		public let i: Int
		public let rect: CGRect
		public let content: CGSize?
		public let alignment: JCSAlign

		public func render() {
			def.cell(at: i)?.draw(in: rect, contentSize: content, alignment: alignment);
		}
	}
	public typealias CellDef = JCSDrawable
	public struct Cells {
		public var count: Int { content.count }
		public let render: (CellRendering)->()
		public let content: [CellDef]

		public init(
			render: ((CellRendering) -> ())? = nil,
			content: [CellDef]
			) {
			self.content = content
			self.render = {
				if let render { render($0) } else { $0.render() }
			}
		}

		public func cell(at i: Int) -> CellDef? {
			i < count ? content[i] : nil
		}
	}

// Definition
	public struct Definition {
		public let columns: [ColumnDef]
		public let rows: Rows
		public let cells: Cells

		public var isEmpty: Bool { columnCount == 0 || cellCount == 0 }
		public var columnCount: Int { columns.count }
		public var wantedRowCount: Int {
			columns.count > 0 ? (cells.count + columns.count - 1) / columns.count : 0
		}
		public var rowCount: Int {
			let wanted = wantedRowCount
			return max(rows.min, min(rows.max, wanted))
		}
		public var cellCount: Int {
			let wantedRows = wantedRowCount
			if wantedRows > rows.max {
				return rows.max * columnCount
			}
			return cells.count
		}
		public func cellIdx(_ c: Int, _ r: Int) -> Int { c + (r * columnCount) }

		public init(
			columns: [ColumnDef],
			rows: Rows,
			cells: Cells
		) {
			self.columns = columns
			self.rows = rows
			self.cells = cells
		}

		public func cell(at i: Int) -> CellDef? {
			cells.cell(at: i)
		}
	}

	public let def: Definition
	public var fixedWidth: Bool { !preparedLayout.hasFillColumns }
	public var fixedHeight: Bool { !preparedLayout.hasFillRows }

	private let preparedLayout: PreparedLayout
	private let fixedLayout: CalculatedLayout?
	private let layoutCache: LayoutCache

	public init(
		flow: ColumnDef, //There is no wrapping
		_ rows: Rows = .init(),
		_ cells: Cells
	) {
		self.init(
			Array(repeating: flow, count: cells.count),
			rows,
			cells)
	}

	public init(
		_ columns: Columns,
		_ rows: Rows = .init(),
		render: ((CellRendering) -> ())? = nil,
		@JCSDrawableBuilder content: ()->[CellDef]
	) {
		self.init(
			columns,
			rows,
			Cells(render: render, content: content()))
	}

	public init(
		flow: ColumnDef, //There is no wrapping
		_ rows: Rows = .init(),
		render: ((CellRendering) -> ())? = nil,
		@JCSDrawableBuilder content: ()->[CellDef]
	) {
		let allContent = content()
		self.init(
			Array(repeating: flow, count: allContent.count),
			rows,
			Cells(render: render, content: allContent))
	}

	// Row/Column sorting should happen outside the Grid.
	// This is not a reactive grid where columns/rows/cells have identity.
	public init(
		_ columns: Columns,
		_ rows: Rows = .init(),
		_ cells: Cells
	) {
		let def = Definition(columns: columns, rows: rows, cells: cells)
		self.def = def
		self.layoutCache = LayoutCache()

		let prepared = Self.prepare(def)
		self.preparedLayout = prepared

		if prepared.hasFill {
			self.fixedLayout = nil
		} else {
			self.fixedLayout = Self.completeLayout(
				def,
				prepared,
				requestedHeight: .unbounded
			)
		}
	}

	private struct PreparedLayout {
		var measured: [CGSize] = []
		var columnWidths: [CGFloat] = []
		var hasFillColumns: Bool = false
		var hasFillRows: Bool = false

		var hasFill: Bool {
			hasFillColumns || hasFillRows
		}
	}

	private struct CalculatedLayout {
		var measured: [CGSize] = []
		var columnWidths: [CGFloat] = []
		var rowHeights: [CGFloat] = []
		var size: CGSize = .zero

		func contentSize(at i: Int) -> CGSize? {
			i < measured.count ? measured[i] : nil
		}
	}

	private static func prepare(_ def: Definition) -> PreparedLayout {
		guard !def.isEmpty else { return .init() }
		let columnCount = def.columnCount
		let rowCount = def.rowCount
		let cellCount = def.cellCount

		var measured = Array(repeating: CGSize.zero, count: cellCount)
		var columnWidths = Array(repeating: CGFloat.zero, count: columnCount)
		var hasFillColumns = false
		var hasFillRows = false

	// Determine if we have fill rows
		for r in 0..<rowCount {
			if case .fill = def.rows.def(r).height {
				hasFillRows = true
				break
			}
		}

	// Measure everything whose width is known without a container width.
		for i in 0..<cellCount {
			let c = i % columnCount
			let column = def.columns[c]
			if let cell = def.cell(at: i) {
				switch column.width {
				case .fixed(let width):
					let size = cell.measure(bounds: CGSize(fixedWidth: width))
					measured[i] = CGSize(width: width, height: size.height)
				case .intrinsic(let bound, let minW):
					measured[i] = cell.measure(bounds: CGSize(fixedWidth: bound))
					if let minW, measured[i].width < minW {
						measured[i].width = minW
						measured[i].height = cell.measure(bounds: CGSize(fixedWidth: minW)).height
					}
				case .uniform:
					measured[i] = cell.measure()
				case .fill:
					hasFillColumns = true
				}
			}
		}
	// Calculate fixed, intrinsic, and preliminary uniform column widths.
		for (c, column) in def.columns.enumerated() {
			switch column.width {
				case .fixed, .intrinsic, .uniform:
					for r in 0..<rowCount {
						let i = def.cellIdx(c, r)
						if i < cellCount {
							columnWidths[c] = max(columnWidths[c], measured[i].width)
						}
					}
				case .fill:
					break
			}
		}
	// Make uniform columns use the widest natural uniform-column width.
		var uniformMax: CGFloat = 0
		var uniformIndex = -1
		for (c, column) in def.columns.enumerated() {
			if case .uniform = column.width, columnWidths[c] > uniformMax {
				uniformMax = columnWidths[c]
				uniformIndex = c
			}
		}
		if uniformIndex != -1 {
			for (c, column) in def.columns.enumerated() {
				if case .uniform = column.width, c != uniformIndex {
					columnWidths[c] = uniformMax
					for r in 0..<rowCount {
						let i = def.cellIdx(c, r)
						if i < cellCount {
							measured[i] = def.cells.content[i].measure(bounds: CGSize(fixedWidth: uniformMax)
							)
						}
					}
				}
			}
		}
		return .init(
			measured: measured,
			columnWidths: columnWidths,
			hasFillColumns: hasFillColumns,
			hasFillRows: hasFillRows
		)
	}

	// Drawable measure
	public func measure(bounds: CGSize) -> CGSize {
		calculatedLayout(for: bounds).size
	}

	// Make decision to call calculateFillColumns
	private static func calculateLayout(
		_ def: Definition,
		_ prep: PreparedLayout,
		for bounds: CGSize
	) -> CalculatedLayout {
		let prepared = prep.hasFillColumns
			? calculateFillColumns(def, prep, for: bounds.width)
			: prep

		return completeLayout(
			def,
			prepared,
			requestedHeight: bounds.height
		)
	}

	private static func calculateFillColumns(
		_ def: Definition,
		_ prep: PreparedLayout,
		for requestedWidth: CGFloat
	) -> PreparedLayout {
		guard !def.isEmpty else { return prep }

		let cellCount = def.cellCount
		let rowCount = def.rowCount
		var measured = prep.measured
		var columnWidths = prep.columnWidths

		var consumedWidth: CGFloat = 0
		var columnsToFill: CGFloat = 0
		var lastGap: CGFloat = 0

		for (c, column) in def.columns.enumerated() {
			switch column.width {
			case .fill(let fraction):
				if fraction == nil || fraction! > 0 {
					columnsToFill += 1
					consumedWidth += column.gap
					lastGap = column.gap
				}
			default:
				let width = columnWidths[c]
				if width > 0 {
					consumedWidth += width + column.gap
					lastGap = column.gap
				}
			}
		}

		if consumedWidth > 0 {
			consumedWidth -= lastGap
		}

		let availableContentWidth = requestedWidth.isUnbounded
			? 0
			: max(requestedWidth - consumedWidth, 0)

		var contentRemaining = availableContentWidth

		for (c, column) in def.columns.enumerated() {
			guard case .fill(let fraction) = column.width else { continue }

			let resolvedFraction: CGFloat
			if let fraction {
				resolvedFraction = fraction
			} else if columnsToFill > 0 {
				resolvedFraction = 1.0 / columnsToFill
			} else {
				resolvedFraction = 0
			}

			let requestedContentWidth = max(
				availableContentWidth * resolvedFraction,
				0
			)
			let contentWidth = min(
				requestedContentWidth,
				contentRemaining
			)

			contentRemaining -= contentWidth

			if contentWidth == 0 {
				contentRemaining = min(
					contentRemaining + column.gap,
					availableContentWidth
				)
			}

			columnWidths[c] = contentWidth

			for r in 0..<rowCount {
				let i = def.cellIdx(c, r)
				if i < cellCount {
					if contentWidth > 0 {
						measured[i] = def.cells.content[i].measure(
							bounds: CGSize(fixedWidth: contentWidth)
						)
					} else {
						measured[i] = .zero
					}
				}
			}
		}

		return .init(
			measured: measured,
			columnWidths: columnWidths,
			hasFillColumns: prep.hasFillColumns,
			hasFillRows: prep.hasFillRows
		)
	}

	private static func completeLayout(
		_ def: Definition,
		_ prep: PreparedLayout,
		requestedHeight: CGFloat
	) -> CalculatedLayout {
		guard !def.isEmpty else { return .init() }

		let columnCount = def.columnCount
		let rowCount = def.rowCount
		let cellCount = def.cellCount
		let measured = prep.measured
		let columnWidths = prep.columnWidths

		var rowHeights = Array(
			repeating: CGFloat.zero,
			count: rowCount
		)

		var uniformMaxHeight: CGFloat = 0
		var fillRowCount: CGFloat = 0

		for r in 0..<rowCount {
			let row = def.rows.def(r)

			switch row.height {
			case .fixed(let height):
				rowHeights[r] = max(height, 0)

			case .intrinsic(let bound, let minHeight):
				for c in 0..<columnCount {
					let i = def.cellIdx(c, r)
					if i < cellCount {
						var height = measured[i].height
						if let minHeight {
							height = max(minHeight, height)
						}
						if !bound.isUnbounded {
							height = min(bound, height)
						}
						rowHeights[r] = max(rowHeights[r], height)
					}
				}

			case .uniform:
				for c in 0..<columnCount {
					let i = def.cellIdx(c, r)
					if i < cellCount {
						uniformMaxHeight = max(
							uniformMaxHeight,
							measured[i].height
						)
					}
				}

			case .fill(let fraction):
				if fraction == nil || fraction! > 0 {
					fillRowCount += 1
				}
				rowHeights[r] = 0
			}
		}

		if uniformMaxHeight > 0 {
			for r in 0..<rowCount {
				if case .uniform = def.rows.def(r).height {
					rowHeights[r] = uniformMaxHeight
				}
			}
		}

		var consumedHeight: CGFloat = 0
		var lastGap: CGFloat = 0

		for r in 0..<rowCount {
			let row = def.rows.def(r)

			switch row.height {
			case .fill(let fraction):
				if fraction == nil || fraction! > 0 {
					consumedHeight += row.gap
					lastGap = row.gap
				}
			default:
				let height = rowHeights[r]
				if height > 0 {
					consumedHeight += height + row.gap
					lastGap = row.gap
				}
			}
		}

		if consumedHeight > 0 {
			consumedHeight -= lastGap
		}

		let availableContentHeight = requestedHeight.isUnbounded
			? 0
			: max(requestedHeight - consumedHeight, 0)

		var contentRemaining = availableContentHeight

		if fillRowCount > 0 {
			for r in 0..<rowCount {
				let row = def.rows.def(r)
				guard case .fill(let fraction) = row.height else { continue }

				let resolvedFraction = fraction ?? (1.0 / fillRowCount)
				let requestedRowHeight = max(
					availableContentHeight * resolvedFraction,
					0
				)
				let rowHeight = min(
					requestedRowHeight,
					contentRemaining
				)

				contentRemaining -= rowHeight

				if rowHeight == 0 {
					contentRemaining = min(
						contentRemaining + row.gap,
						availableContentHeight
					)
				}

				rowHeights[r] = rowHeight
			}
		}

		var size = CGSize.zero
		for c in 0..<columnCount {
			let width = columnWidths[c]
			if width > 0 {
				size.width += width
				if c != columnCount - 1 {
					size.width += def.columns[c].gap
				}
			}
		}
		for r in 0..<rowCount {
			let height = rowHeights[r]
			if height > 0 {
				size.height += height
				if r != rowCount - 1 {
					size.height += def.rows.def(r).gap
				}
			}
		}

		return .init(
			measured: measured,
			columnWidths: columnWidths,
			rowHeights: rowHeights,
			size: size
		)
	}

	// Drawable draw
	public func draw(in srcRect: CGRect, contentSize: CGSize, alignment: JCSAlign) {
		let rect = alignment.apply(size: contentSize, in: srcRect)
		let calculated = calculatedLayout(for: rect.size)
		let origin = rect.origin
		let maxX = rect.maxX
		let maxY = rect.maxY
		let columnCount = def.columnCount
		let rowCount = def.rowCount
		var cx = origin.x
		for c in 0..<columnCount {
			if cx > maxX { break }
			let width = calculated.columnWidths[c]
			let column = def.columns[c]
			if width > 0 {
				if let render = column.render {
					let rendering = ColumnRendering(
						def: def,
						c: c,
						rect: CGRect(x: cx, y: origin.y, width: width, height: calculated.size.height)
					)
					render(rendering)
				}
				cx += width + column.gap
			}
		}
		var ry = origin.y
		for r in 0..<rowCount {
			if ry > maxY { break }
			let height = calculated.rowHeights[r]
			if height > 0 {
				let row = def.rows.def(r)
				if let render = row.render {
					let rendering = RowRendering(
						def: def,
						row: row,
						r: r,
						rect: CGRect(x: origin.x, y: ry, width: calculated.size.width, height: height )
					)
					render(rendering)
				}
				ry += height + row.gap
			}
		}
		var x = origin.x
		for c in 0..<columnCount {
			if x > maxX { break }
			let width = calculated.columnWidths[c]
			let column = def.columns[c]
			if width > 0 {
				var y = origin.y
				for r in 0..<rowCount {
					if y > maxY { break }
					let height = calculated.rowHeights[r]
					if height > 0 {
						let row = def.rows.def(r)
						let i = def.cellIdx(c, r)
						let cellOrigin = CGPoint(x: x, y: y)
						let cellSize = CGSize(width: width, height: height)
						let contentSize = calculated.contentSize(at: i)
						let alignment = column.align.union(row.align)
						let cellRect = CGRect(origin: cellOrigin, size: cellSize)
						let rendering = CellRendering(
							def: def,
							c: c,
							r: r,
							i: i,
							rect: cellRect,
							content: contentSize,
							alignment: alignment
						)
						def.cells.render(rendering)
						y += height + row.gap
					}
				}
				x += width + column.gap
			}
		}
	}

	// Make decision to return fixedLayout or access cache (for fills)
	private func calculatedLayout(
		for bounds: CGSize
	) -> CalculatedLayout {
		if let fixedLayout {
			return fixedLayout
		}
		return layoutCache.request(bounds) {
			Self.calculateLayout(
				def,
				preparedLayout,
				for: $0
			)
		}
	}

	private final class LayoutCache {
		private var key: CGSize?
		private var calculated: CalculatedLayout?

		init() {}

		func request(
			_ bounds: CGSize,
			_ calculate: (CGSize) -> CalculatedLayout
		) -> CalculatedLayout {
			let requestKey = normalize(bounds)

			if let calculated, key == requestKey {
				return calculated
			}

			key = requestKey
			let calculated = calculate(requestKey)
			self.calculated = calculated
			return calculated
		}

		func normalize(_ key: CGSize) -> CGSize {
			key
		}
	}
}
