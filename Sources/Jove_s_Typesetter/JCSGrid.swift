import CoreGraphics

public struct JCSGrid: JCSLayoutElement {
// TODO: Feature - Pivot Table
// TODO: Feature - Wrapping 'wrapping: JCSAxis?'
//     hits bottom, sets y = 0 and x+=width, measured width needs to account
//     hits right, sets x = 0 and y+=height, measured height needs to account
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
		//wrap: Bool = false,
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
		//wrap: Bool = false,
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
		//wrap: Bool = false,
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
		//wrap: Bool = false,
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
		//wrap: JCSAxis? = nil,
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
		var columnSize: CGFloat = 0
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
			var intrinsicColumnWidths = Array(
				repeating: CGFloat.zero,
				count: columnCount
			)

			let columns = JCSDimension.apply(
				to: cols,
				dimension: \.width,
				gap: \.gap,
				available: .unbounded,
				intrinsic: { c, column, bound in
					var width: CGFloat = 0
					for r in 0..<rowCount {
						let i = cellIdx(c, r)
						guard i < cellCount else { continue }
						let size = cells[i].measure(
							bounds: CGSize(fixedWidth: bound)
						)
						measured[i] = size
						width = max(width, size.width)
					}
					intrinsicColumnWidths[c] = width
					return width
				},
				didResolve: { c, column, width in
					switch column.width {
					case .fixed:
						measureColumn(c, width: width, into: &measured)
					case .intrinsic(_, let minimum):
						guard minimum != nil else { return }
						for r in 0..<rowCount {
							let i = cellIdx(c, r)
							guard i < cellCount, measured[i].width < width else {
								continue
							}
							measured[i] = cells[i].measure(
								bounds: CGSize(fixedWidth: width)
							)
						}
					case .uniform:
						if intrinsicColumnWidths[c] != width {
							measureColumn(c, width: width, into: &measured)
						}
					case .fill:
						break
					}
				}
			)

			let hasFillRows = rowDefs.contains {
				if case .fill = $0.height { return true }
				return false
			}

			return .init(
				measured: measured,
				columnWidths: columns.values,
				columnSize: columns.size,
				rowDefs: rowDefs,
				hasFillColumns: columns.hasFill,
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
			var measured = prep.measured
			let preparedColumns = JCSDimension.Applied(
				values: prep.columnWidths,
				hasFill: prep.hasFillColumns
			)

			let columns = JCSDimension.apply(
				to: cols,
				dimension: \.width,
				gap: \.gap,
				available: requestedWidth,
				prepared: preparedColumns,
				intrinsic: { _, _, _ in
					preconditionFailure("Prepared columns must not be remeasured.")
				},
				didResolve: { c, column, width in
					guard case .fill = column.width else { return }
					measureColumn(c, width: width, into: &measured)
				}
			)

			return .init(
				measured: measured,
				columnWidths: columns.values,
				columnSize: columns.size,
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
			let cellCount = cellCount

			let rows = JCSDimension.apply(
				to: prep.rowDefs,
				dimension: \.height,
				gap: \.gap,
				available: requestedHeight,
				intrinsic: { r, _, _ in
					var height: CGFloat = 0
					for c in 0..<columnCount {
						let i = cellIdx(c, r)
						if i < cellCount {
							height = max(height, prep.measured[i].height)
						}
					}

					return height
				}
			)
			return .init(
				measured: prep.measured,
				columnWidths: prep.columnWidths,
				rowDefs: prep.rowDefs,
				rowHeights: rows.values,
				size: CGSize(width: prep.columnSize, height: rows.size)
			)
		}

		private func measureColumn(
			_ c: Int,
			width: CGFloat,
			into measured: inout [CGSize]
		) {
			let rowCount = rowCount
			let cellCount = cellCount

			for r in 0..<rowCount {
				let i = cellIdx(c, r)
				guard i < cellCount else { continue }
				measured[i] = width > 0
					? cells[i].measure(bounds: CGSize(fixedWidth: width))
					: .zero
			}
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
						x += width + column.gap
					}
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
