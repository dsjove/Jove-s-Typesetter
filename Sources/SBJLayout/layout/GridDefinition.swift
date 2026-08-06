import CoreGraphics

public struct GridDefinition<Cell: TrackElement> {
	public struct TrackIteration {
		public let definition: GridDefinition
		public let track: Track
		public let index: Int
		public let rect: CGRect
	}
	public typealias ColumnIteration = TrackIteration
	public typealias RowIteration = TrackIteration

	public struct CellIteration {
		public let definition: GridDefinition
		public let cell: Cell?
		public let c: Int
		public let r: Int
		public let i: Int
		public let rect: CGRect
		public let content: CGSize?
		public let alignment: Alignment
	}

	// Grid specification.
	public let columnFactory: TrackFactory
	public let rowFactory: TrackFactory
	public let cells: [Cell]
	public let arrangement: TrackArrangement

	// Resolved layout snapshot.
	public let columns: TrackMetrics
	public let rows: TrackMetrics
	public let measured: [CGSize]
	public let bounds: CGSize?

	public init(
		columns: TrackFactory,
		rows: TrackFactory = .init(),
		cells: [Cell],
		layout: TrackArrangement = .gaps
	) {
		self.init(
			columnFactory: columns,
			rowFactory: rows,
			cells: cells,
			arrangement: layout,
			columns: .init(),
			rows: .init(),
			measured: Array(repeating: .zero, count: cells.count),
			bounds: nil
		)
	}

	private init(
		columnFactory: TrackFactory,
		rowFactory: TrackFactory,
		cells: [Cell],
		arrangement: TrackArrangement,
		columns: TrackMetrics,
		rows: TrackMetrics,
		measured: [CGSize],
		bounds: CGSize?
	) {
		self.columnFactory = columnFactory
		self.rowFactory = rowFactory
		self.cells = cells
		self.arrangement = arrangement
		self.columns = columns
		self.rows = rows
		self.measured = measured
		self.bounds = bounds
	}

	public var columnCount: Int {
		columnFactory.max - columnFactory.min + 1
	}

	public var columnLayout: TrackLayout {
		.init(
			factory: columnFactory.def,
			count: columnCount,
			layout: arrangement)
	}

	public var rowLayout: TrackLayout {
		.init(
			factory: rowFactory.def,
			count: rowCount,
			layout: arrangement)
	}

	public var wantedRowCount: Int {
		columnCount > 0 ? (cells.count + columnCount - 1) / columnCount : 0
	}

	public var rowCount: Int {
		max( 0, max(rowFactory.min, Swift.min(rowFactory.max, wantedRowCount)))
	}

	public var cellCount: Int {
		rowFactory.max > 0 ? min(cells.count, rowCount * columnCount) : 0
	}

	public var isEmpty: Bool {
		columnCount == 0 || cellCount == 0
	}

	public var size: CGSize {
		.init(width: columns.size, height: rows.size)
	}

	public func resolving(
		bounds: CGSize,
		columns: TrackMetrics,
		rows: TrackMetrics,
		measured: [CGSize]
	) -> Self {
		.init(
			columnFactory: columnFactory,
			rowFactory: rowFactory,
			cells: cells,
			arrangement: arrangement,
			columns: columns,
			rows: rows,
			measured: measured,
			bounds: bounds
		)
	}

	public func cellIdx(_ c: Int, _ r: Int) -> Int {
		c + (r * columnCount)
	}

	public func cell(at index: Int) -> Cell? {
		guard index >= 0, index < cellCount else { return nil }
		return cells.indices.contains(index) ? cells[index] : nil
	}

	public func measuredSize(at index: Int) -> CGSize? {
		guard index >= 0, index < cellCount else { return nil }
		return measured.indices.contains(index) ? measured[index] : nil
	}

	public func forEachCell(inColumn column: Int, _ body: (_ index: Int) -> Void) {
		guard column >= 0, column < columnCount else { return }
		for row in 0..<rowCount {
			let index = cellIdx(column, row)
			guard index < cellCount else { continue }
			body(index)
		}
	}

	public func forEachCell(inRow row: Int, _ body: (_ index: Int) -> Void) {
		guard row >= 0, row < rowCount else { return }
		for column in 0..<columnCount {
			let index = cellIdx(column, row)
			guard index < cellCount else { continue }
			body(index)
		}
	}

	public func allocatedRect(_ origin: CGPoint = .zero, column: Int) -> CGRect {
		.init(
			x: origin.x + columns.offsets[column],
			y: origin.y,
			width: columns.lengths[column],
			height: rows.size
		)
	}

	public func allocatedRect(_ origin: CGPoint = .zero, row: Int) -> CGRect {
		.init(
			x: origin.x,
			y: origin.y + rows.offsets[row],
			width: columns.size,
			height: rows.lengths[row]
		)
	}

	public func allocatedRect(_ origin: CGPoint = .zero, column: Int, row: Int) -> CGRect {
		.init(
			x: origin.x + columns.offsets[column],
			y: origin.y + rows.offsets[row],
			width: columns.lengths[column],
			height: rows.lengths[row]
		)
	}

	public func iterate(
		allocated: CGRect = CGRect(origin: .zero, size: .unbounded),
		truncate: Bool = false,
		column rColumn: ((ColumnIteration) -> Void)? = nil,
		row rRow: ((RowIteration) -> Void)? = nil,
		cell rCell: @escaping (CellIteration) -> Void
	) {
		let origin = allocated.origin
		let maxX = allocated.maxX
		let maxY = allocated.maxY

		if let rColumn {
			for c in 0..<columnCount {
				let rect = allocatedRect(origin, column: c)
				if (truncate ? rect.maxX : rect.minX) > maxX { break }
				if rect.size.isEmpty { continue }
				rColumn(.init(
					definition: self,
					track: columns.tracks[c],
					index: c,
					rect: rect
				))
			}
		}
		for r in 0..<rowCount {
			let rowRect = allocatedRect(origin, row: r)
			if (truncate ? rowRect.maxY : rowRect.minY) > maxY { break }
			if rowRect.size.isEmpty { continue }
			let row = rows.tracks[r]
			let rowAlignment = row.align
			if let rRow {
				rRow(.init(
					definition: self,
					track: row,
					index: r,
					rect: rowRect
				))
			}
			for c in 0..<columnCount {
				let rect = allocatedRect(origin, column: c, row: r)
				if (truncate ? rect.maxX : rect.minX) > maxX { break }
				if rect.size.isEmpty { continue }
				let i = cellIdx(c, r)
				let columnAlignment = columns.tracks[c].align
				rCell(.init(
					definition: self,
					cell: cell(at: i),
					c: c,
					r: r,
					i: i,
					rect: rect,
					content: measuredSize(at: i),
					alignment: rowAlignment.union(columnAlignment)
				))
			}
		}
	}
}
