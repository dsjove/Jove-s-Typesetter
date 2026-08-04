import CoreGraphics

public struct GridMetrics {
	public let columns: TrackMetrics
	public let rows: TrackMetrics
	public let measured: [CGSize]

	public init(
		columns: TrackMetrics,
		rows: TrackMetrics,
		measured: [CGSize]
	) {
		self.columns = columns
		self.rows = rows
		self.measured = measured
	}

	public var size: CGSize {
		.init(width: columns.size, height: rows.size)
	}

	public func measuredSize(at index: Int) -> CGSize? {
		measured.indices.contains(index) ? measured[index] : nil
	}

	public func allocatedRect(
		_ origin: CGPoint = .zero,
		column: Int
	) -> CGRect {
		.init(
			x: origin.x + columns.offsets[column],
			y: origin.y,
			width: columns.lengths[column],
			height: rows.size
		)
	}

	public func allocatedRect(
		_ origin: CGPoint = .zero,
		row: Int
	) -> CGRect {
		.init(
			x: origin.x,
			y: origin.y + rows.offsets[row],
			width: columns.size,
			height: rows.lengths[row]
		)
	}

	public func allocatedRect(
		_ origin: CGPoint = .zero,
		column: Int,
		row: Int
	) -> CGRect {
		.init(
			x: origin.x + columns.offsets[column],
			y: origin.y + rows.offsets[row],
			width: columns.lengths[column],
			height: rows.lengths[row]
		)
	}
}

public final class GridLayout<Element: TrackElement> {
	public typealias Cell = Element

	public struct TrackIteration {
		public let metrics: GridMetrics
		public let track: Track
		public let index: Int
		public let rect: CGRect
	}
	public typealias ColumnIteration = TrackIteration
	public typealias RowIteration = TrackIteration
	public struct CellIteration {
		public let metrics: GridMetrics
		public let cell: Cell?
		public let c: Int
		public let r: Int
		public let i: Int
		public let rect: CGRect
		public let content: CGSize?
		public let alignment: Alignment
	}

	public let cells: [Cell]
	public let columns: TrackLayout
	public let rows: TrackLayout
	public let minRows: Int
	public let maxRows: Int

	public var isEmpty: Bool { columnCount == 0 || cellCount == 0 }
	public var columnCount: Int { columns.count }
	public var wantedRowCount: Int {
		columnCount > 0 ? (cells.count + columnCount - 1) / columnCount : 0
	}
	public var rowCount: Int {
		max(0, max(minRows, min(maxRows, wantedRowCount)))
	}
	public var cellCount: Int {
		maxRows > 0 ? Swift.min(cells.count, rowCount * columnCount) : 0
	}
	public func cellIdx(_ c: Int, _ r: Int) -> Int {
		c + (r * columnCount)
	}
	public func cell(at i: Int) -> Element? {
		cells.indices.contains(i) ? cells[i] : nil
	}

	private struct Measurement {
		let bounds: CGSize
		let size: CGSize
	}
	private var measurements: [Measurement?]
	private var measurementRevision: UInt = 0

	public init(
		columns: [Track],
		rows: TrackFactory = .init(),
		cells: [Element],
		layout: TrackArrangement = .gaps
	) {
		self.columns = TrackLayout(
			tracks: columns,
			layout: layout
		)

		let columnCount = columns.count
		let wantedRowCount = columnCount > 0
			? (cells.count + columnCount - 1) / columnCount : 0
		let rowCount = max(0, max(rows.min, min(rows.max, wantedRowCount)))

		self.rows = TrackLayout(
			factory: rows.def,
			count: rowCount,
			layout: layout
		)
		self.minRows = rows.min
		self.maxRows = rows.max
		self.cells = cells
		self.measurements = Array(repeating: nil, count: cells.count)
	}

	public func measure(bounds: CGSize) -> GridMetrics {
		columns.apply(
			available: bounds.width,
			intrinsic: intrinsicColumnWidth
		)

		let revisionBeforeResolvedMeasurement = measurementRevision
		measureElementsForResolvedColumns()
		if measurementRevision != revisionBeforeResolvedMeasurement {
			rows.invalidate()
		}

		rows.apply(
			available: bounds.height,
			intrinsic: intrinsicRowHeight
		)

		return GridMetrics(
			columns: columns.metrics,
			rows: rows.metrics,
			measured: measurements.map { $0?.size ?? .zero }
		)
	}

	public func iterate(
		metrics: GridMetrics,
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
				let rect = metrics.allocatedRect(origin, column: c)
				if (truncate ? rect.maxX : rect.minX) > maxX { break }
				if rect.size.isEmpty { continue }
				rColumn(.init(
					metrics: metrics,
					track: metrics.columns.tracks[c],
					index: c,
					rect: rect
				))
			}
		}
		for r in 0..<rowCount {
			let rowRect = metrics.allocatedRect(origin, row: r)
			if (truncate ? rowRect.maxY : rowRect.minY) > maxY { break }
			if rowRect.size.isEmpty { continue }
			let row = metrics.rows.tracks[r]
			let rowAlignment = row.align
			if let rRow {
				rRow(.init(
					metrics: metrics,
					track: row,
					index: r,
					rect: rowRect
				))
			}
			for c in 0..<columnCount {
				let rect = metrics.allocatedRect(origin, column: c, row: r)
				if (truncate ? rect.maxX : rect.minX) > maxX { break }
				if rect.size.isEmpty { continue }
				let i = cellIdx(c, r)
				let columnAlignment = metrics.columns.tracks[c].align
				rCell(.init(
					metrics: metrics,
					cell: cell(at: i),
					c: c,
					r: r,
					i: i,
					rect: rect,
					content: metrics.measuredSize(at: i),
					alignment: rowAlignment.union(columnAlignment)
				))
			}
		}
	}

	private func intrinsicColumnWidth(
		_ column: Int,
		_ definition: Track,
		_ bound: CGFloat
	) -> CGFloat {
		var width: CGFloat = 0
		for row in 0..<rowCount {
			let index = cellIdx(column, row)
			guard index < cellCount else {
				continue
			}
			let size = measureElement(
				at: index,
				bounds: CGSize(width: bound, height: .unbounded)
			)
			width = Swift.max(width, size.width)
		}
		return width
	}

	private func measureElementsForResolvedColumns() {
		for column in 0..<columnCount {
			guard columns.lengths.indices.contains(column) else {
				continue
			}
			let width = columns.lengths[column]
			let resolvedBounds = CGSize(width: width, height: .unbounded)
			for row in 0..<rowCount {
				let index = cellIdx(column, row)
				guard index < cellCount else {
					continue
				}
				guard width > 0 else {
					setMeasurement(
						at: index,
						Measurement(bounds: resolvedBounds, size: .zero)
					)
					continue
				}
				if canReuseIntrinsicMeasurement(
					at: index,
					resolvedWidth: width
				) {
					continue
				}
				_ = measureElement(at: index, bounds: resolvedBounds)
			}
		}
	}

	private func canReuseIntrinsicMeasurement(
		at index: Int,
		resolvedWidth: CGFloat
	) -> Bool {
		guard let cached = measurements[index] else {
			return false
		}
		return cached.bounds.width == .unbounded
			&& cached.bounds.height == .unbounded
			&& cached.size.width == resolvedWidth
	}

	private func intrinsicRowHeight(
		_ row: Int,
		_ definition: Track,
		_ bound: CGFloat
	) -> CGFloat {
		var height: CGFloat = 0
		for column in 0..<columnCount {
			let index = cellIdx(column, row)
			guard index < cellCount else {
				continue
			}
			height = Swift.max(
				height,
				measurements[index]?.size.height ?? 0
			)
		}
		return height
	}

	private func setMeasurement(at index: Int, _ measurement: Measurement) {
		guard measurements.indices.contains(index) else { return }
		let previous = measurements[index]
		if previous?.bounds != measurement.bounds || previous?.size != measurement.size {
			measurementRevision &+= 1
		}
		measurements[index] = measurement
	}

	@discardableResult
	private func measureElement(
		at index: Int,
		bounds: CGSize
	) -> CGSize {
		guard cells.indices.contains(index) else {
			return .zero
		}
		if let cached = measurements[index], cached.bounds == bounds {
			return cached.size
		}
		let size = cells[index].measure(bounds: bounds)
		setMeasurement(
			at: index,
			Measurement(bounds: bounds, size: size)
		)
		return size
	}
}
