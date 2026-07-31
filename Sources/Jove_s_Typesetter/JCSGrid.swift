import CoreGraphics

public struct JCSGrid: JCSLayoutElement {
// TODO: Feature - Pivot Table
// TODO: Feature - Wrapping 'wrapping: JCSAxis?'
//     hits bottom, sets y = 0 and x+=width, measured width needs to account
//     hits right, sets x = 0 and y+=height, measured height needs to account
// TODO: Bug - use uniform accume function
// TODO: Bug - for rows and columns, if there are several zero-sized elements at the end, we will have an extra gap
// TODO: Bug - do copy-on-write for Layout member

// Columns
	public struct ColumnDef {
		public let width: JCSDimension
		public let align: JCSAlignment
		public let gap: CGFloat

		public init(
			width: JCSDimension = .intrinsic(),
			align: JCSAlignment = .left,
			gap: CGFloat = 2.0
		) {
			self.width = width
			self.align = align
			self.gap = gap
		}
	}
	public typealias Columns = [ColumnDef]

// Rows
	public struct RowDef {
		public let height: JCSDimension
		public let align: JCSAlignment
		public let gap: CGFloat

		public init(
			height: JCSDimension = .intrinsic(),
			align: JCSAlignment = .top,
			gap: CGFloat = 2.0
		) {
			self.height = height
			self.align = align
			self.gap = gap
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
	public typealias CellDef = JCSLayoutElement
	public typealias Cells = [CellDef]

// Rendering
	public struct ColumnRender {
		public let spec: Specification
		public let def: ColumnDef
		public let c: Int
		public let rect: CGRect
	}
	public struct RowRender {
		public let spec: Specification
		public let row: RowDef
		public let r: Int
		public let rect: CGRect
	}
	public struct CellRender {
		public let spec: Specification
		public let def: CellDef?
		public let c: Int
		public let r: Int
		public let i: Int
		public let rect: CGRect
		public let content: CGSize?
		public let alignment: JCSAlignment

		public func render() {
			def?.draw(in: rect, measured: content, align: alignment);
		}
	}
	public struct Render {
		public let col: ((ColumnRender)->())?
		public let row: ((RowRender)->())?
		public let cell: (CellRender)->()

		public init(
			col: ((ColumnRender) -> ())? = nil,
			row: ((RowRender) -> ())? = nil,
			cell: ((CellRender) -> ())? = nil
		) {
			self.col = col
			self.row = row
			self.cell = {
				if let cell { cell($0) } else { $0.render() }
			}
		}
	}

// Members
	private let layout: Layout

// API
	public init(
		horzFlow col: ColumnDef,
		rows: Rows = .init(),
		cells: Cells
	) {
		self.init(
			cols: Array(repeating: col, count: cells.count),
			rows: rows,
			cells: cells)
	}

	public init(
		horzFlow col: ColumnDef,
		rows: Rows = .init(),
		@JCSLayoutElementBuilder cells: ()->[CellDef]
	) {
		self.init(
			horzFlow: col,
			rows: rows,
			cells: cells())
	}

	public init(
		vertFlow col: ColumnDef,
		rows: Rows = .init(),
		cells: Cells
	) {
		self.init(
			cols: [col],
			rows: rows,
			cells: cells)
	}

	public init(
		vertFlow col: ColumnDef,
		rows: Rows = .init(),
		@JCSLayoutElementBuilder cells: ()->[CellDef]
	) {
		self.init(
			vertFlow: col,
			rows: rows,
			cells: cells())
	}

	public init(
		cols: Columns,
		rows: Rows = .init(),
		@JCSLayoutElementBuilder cells: ()->[CellDef]
	) {
		self.init(
			cols: cols,
			rows: rows,
			cells: cells())
	}

	// Row/Column sorting should happen outside the Grid.
	// This is not a reactive grid where columns/rows/cells have identity.
	public init(
		cols: Columns,
		rows: Rows = .init(),
		render: Render = .init(),
		cells: Cells
	) {
		let spec = Specification(cols: cols, rows: rows, cells: cells, render: render)
		self.layout = .init(spec: spec)
	}

	public func measure(bounds: CGSize) -> CGSize {
		layout.calculateLayout(for: bounds).size
	}

	public func draw(in allocated: CGRect, measured: CGSize, align: JCSAlignment) {
		layout.draw(allocated, measured, align)
	}

// Implementation
	internal class Layout {
		let spec: Specification
		var prep: PreparedLayout?
		var fixed: CalculatedLayout?
		var key: CGSize?
		var calculated: CalculatedLayout?

		var fixedWidth: Bool { !(prep?.hasFillColumns ?? false)}
		var fixedHeight: Bool { !(prep?.hasFillRows ?? false)}
		var intrinsicSize: CGSize { fixed?.size ?? (calculated?.size ?? .zero) }

		init(spec: Specification) {
			self.spec = spec
		}

		func normalize(_ key: CGSize) -> CGSize {
			key
		}

		func calculateLayout(for bounds: CGSize) -> CalculatedLayout {
			if let fixed {
				return fixed
			}

			let prepared: PreparedLayout
			if let prepped = prep {
				prepared = prepped
			} else {
				prepared = spec.prepare()
				prep = prepared
				if prepared.hasFill {
					fixed = nil
				} else {
					fixed = spec.completeLayout(prepared, requestedHeight: .unbounded)
				}
			}

			let requestKey = normalize(bounds)
			if let calculated, key == requestKey {
				return calculated
			}
			key = requestKey
			let calculated = spec.calculateLayout(prepared, for: bounds)
			self.calculated = calculated
			return calculated
		}

		func draw(_ allocated: CGRect, _ measured: CGSize, _ align: JCSAlignment) {
//TODO: Bug rect not always correct
			let rect = align.apply(size: intrinsicSize, in: allocated)
			spec.draw(calculateLayout(for: measured), rect)
		}
	}

	internal struct CalculatedLayout {
		var measured: [CGSize] = []
		var columnWidths: [CGFloat] = []
		var rowDefs: [RowDef] = []
		var rowHeights: [CGFloat] = []
		var size: CGSize = .zero

		func contentSize(at i: Int) -> CGSize? {
			i < measured.count ? measured[i] : nil
		}
	}

	internal struct PreparedLayout {
		var measured: [CGSize] = []
		var columnWidths: [CGFloat] = []
		var rowDefs: [RowDef] = []
		var hasFillColumns: Bool = false
		var hasFillRows: Bool = false

		var hasFill: Bool {
			hasFillColumns || hasFillRows
		}
	}

	public struct Specification {
		public let cols: [ColumnDef]
		public let rows: Rows
		public let cells: Cells
		public let render: Render

		public init(
			cols: [ColumnDef],
			rows: Rows,
			cells: Cells,
			render: Render
		) {
			self.cols = cols
			self.rows = rows
			self.cells = cells
			self.render = render
		}

		public var isEmpty: Bool { columnCount == 0 || cellCount == 0 }
		public var columnCount: Int { cols.count }
		public var wantedRowCount: Int {
			cols.count > 0 ? (cells.count + cols.count - 1) / cols.count : 0
		}
		public var rowCount: Int {
			let wanted = wantedRowCount
			return Swift.max(0, Swift.max(rows.min, Swift.min(rows.max, wanted)))
		}
		public var cellCount: Int {
			guard rows.max > 0 else { return 0 }
			let wantedRows = wantedRowCount
			if wantedRows > rows.max {
				return rows.max * columnCount
			}
			return cells.count
		}
		public func cellIdx(_ c: Int, _ r: Int) -> Int {
			c + (r * columnCount)
		}
		public func cell(at i: Int) -> CellDef? {
			i < 0 || i >= cells.count ? nil : cells[i]
		}

		internal func prepare() -> PreparedLayout {
			guard !isEmpty else { return .init() }
			let columnCount = columnCount
			let rowCount = rowCount
			let cellCount = cellCount
			let rowDefs = (0..<rowCount).map(rows.def)

			var measured = Array(repeating: CGSize.zero, count: cellCount)
			var columnWidths = Array(repeating: CGFloat.zero, count: columnCount)
			var hasFillColumns = false
			var hasFillRows = false

			for row in rowDefs {
				if case .fill = row.height {
					hasFillRows = true
					break
				}
			}
			for i in 0..<cellCount {
				let c = i % columnCount
				let column = cols[c]
				if let cell = cell(at: i) {
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
			for (c, column) in cols.enumerated() {
				switch column.width {
					case .fixed, .intrinsic, .uniform:
						for r in 0..<rowCount {
							let i = cellIdx(c, r)
							if i < cellCount {
								columnWidths[c] = max(columnWidths[c], measured[i].width)
							}
						}
					case .fill:
						break
				}
			}
			var uniformMax: CGFloat = 0
			var uniformIndex = -1
			for (c, column) in cols.enumerated() {
				if case .uniform = column.width, columnWidths[c] > uniformMax {
					uniformMax = columnWidths[c]
					uniformIndex = c
				}
			}
			if uniformIndex != -1 {
				for (c, column) in cols.enumerated() {
					if case .uniform = column.width, c != uniformIndex {
						columnWidths[c] = uniformMax
						for r in 0..<rowCount {
							let i = cellIdx(c, r)
							if i < cellCount {
								measured[i] = cells[i].measure(bounds: CGSize(fixedWidth: uniformMax)
								)
							}
						}
					}
				}
			}
			return .init(
				measured: measured,
				columnWidths: columnWidths,
				rowDefs: rowDefs,
				hasFillColumns: hasFillColumns,
				hasFillRows: hasFillRows
			)
		}

		internal func calculateLayout(
			_ prep: PreparedLayout,
			for bounds: CGSize
		) -> CalculatedLayout {
			let prepared = prep.hasFillColumns
				? calculateFillColumns(prep, for: bounds.width)
				: prep
			return completeLayout(prepared, requestedHeight: bounds.height)
		}

		internal func calculateFillColumns(
			_ prep: PreparedLayout,
			for requestedWidth: CGFloat
		) -> PreparedLayout {
			guard !isEmpty else { return prep }

			let cellCount = cellCount
			let rowCount = rowCount
			var measured = prep.measured
			var columnWidths = prep.columnWidths

			var consumedWidth: CGFloat = 0
			var columnsToFill: CGFloat = 0
			var lastGap: CGFloat = 0

			for (c, column) in cols.enumerated() {
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

			for (c, column) in cols.enumerated() {
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
					let i = cellIdx(c, r)
					if i < cellCount {
						if contentWidth > 0 {
							measured[i] = cells[i].measure(
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
				rowDefs: prep.rowDefs,
				hasFillColumns: prep.hasFillColumns,
				hasFillRows: prep.hasFillRows
			)
		}

		internal func completeLayout(
			_ prep: PreparedLayout,
			requestedHeight: CGFloat
		) -> CalculatedLayout {
			guard !isEmpty else { return .init() }

			let columnCount = columnCount
			let rowCount = rowCount
			let cellCount = cellCount
			let measured = prep.measured
			let columnWidths = prep.columnWidths
			let rowDefs = prep.rowDefs

			var rowHeights = Array(
				repeating: CGFloat.zero,
				count: rowCount
			)

			var uniformMaxHeight: CGFloat = 0
			var fillRowCount: CGFloat = 0

			for r in 0..<rowCount {
				let row = rowDefs[r]

				switch row.height {
				case .fixed(let height):
					rowHeights[r] = max(height, 0)
				case .intrinsic(let bound, let minHeight):
					for c in 0..<columnCount {
						let i = cellIdx(c, r)
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
						let i = cellIdx(c, r)
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
					if case .uniform = rowDefs[r].height {
						rowHeights[r] = uniformMaxHeight
					}
				}
			}

			var consumedHeight: CGFloat = 0
			var lastGap: CGFloat = 0

			for r in 0..<rowCount {
				let row = rowDefs[r]
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
					let row = rowDefs[r]
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
						size.width += cols[c].gap
					}
				}
			}
			for r in 0..<rowCount {
				let height = rowHeights[r]
				if height > 0 {
					size.height += height
					if r != rowCount - 1 {
						size.height += rowDefs[r].gap
					}
				}
			}

			return .init(
				measured: measured,
				columnWidths: columnWidths,
				rowDefs: prep.rowDefs,
				rowHeights: rowHeights,
				size: size
			)
		}

		internal func draw(_ layout: CalculatedLayout, _ rect: CGRect) {
			let maxX = rect.maxX
			let maxY = rect.maxY
			let columnCount = columnCount
			let rowCount = rowCount
			let rowDefs = layout.rowDefs

			if let render = render.col {
				var x = rect.minX
				for c in 0..<columnCount {
					if x > maxX { break }
					let width = layout.columnWidths[c]
					let column = cols[c]
					if width > 0 {
						let rendering = ColumnRender(
							spec: self,
							def: column,
							c: c,
							rect: CGRect(x: x, y: rect.minY, width: width, height: layout.size.height)
						)
						render(rendering)
					}
					x += width + column.gap
				}
			}
			if let render = render.row {
				var y = rect.minY
				for r in 0..<rowCount {
					if y > maxY { break }
					let height = layout.rowHeights[r]
					if height > 0 {
						let row = rowDefs[r]
						let rendering = RowRender(
							spec: self,
							row: row,
							r: r,
							rect: CGRect(x: rect.minX, y: y, width: layout.size.width, height: height )
						)
						render(rendering)
						y += height + row.gap
					}
				}
			}
			var x = rect.minX
			for c in 0..<columnCount {
				if x > maxX { break }
				let width = layout.columnWidths[c]
				let column = cols[c]
				if width > 0 {
					var y = rect.minY
					for r in 0..<rowCount {
						if y > maxY { break }
						let height = layout.rowHeights[r]
						if height > 0 {
							let row = rowDefs[r]
							let i = cellIdx(c, r)
							let cellOrigin = CGPoint(x: x, y: y)
							let cellSize = CGSize(width: width, height: height)
							let contentSize = layout.contentSize(at: i)
							let alignment = column.align.union(row.align)
							let cellRect = CGRect(origin: cellOrigin, size: cellSize)
							let rendering = CellRender(
								spec: self,
								def: cell(at: i),
								c: c,
								r: r,
								i: i,
								rect: cellRect,
								content: contentSize,
								alignment: alignment
							)
							render.cell(rendering)
							y += height + row.gap
						}
					}
					x += width + column.gap
				}
			}
		}
	}
}
