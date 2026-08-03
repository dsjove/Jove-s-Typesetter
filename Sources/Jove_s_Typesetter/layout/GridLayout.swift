import CoreGraphics

public final class GridLayout<Element: TrackElement> {
	public let cells: [Element]
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
		max(0, max(minRows, min(maxRows, wantedRowCount))
		)
	}
	public var cellCount: Int {
		maxRows > 0 ? min(cells.count, rowCount * columnCount) : 0
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

	public init(
		columns columnDefs: [Track],
		rows rowFactory: TrackFactory = .init(),
		cells: [Element],
		layout: TrackArrangement = .gaps
	) {
		self.columns = TrackLayout(
			elements: columnDefs,
			layout: layout
		)
		let columnCount = columnDefs.count
		let wantedRowCount = columnCount > 0
			? (cells.count + columnCount - 1) / columnCount
			: 0
		let rowCount = max(0, max(rowFactory.min, min(rowFactory.max, wantedRowCount)))
		self.rows = TrackLayout(
			factory: rowFactory.def,
			count: rowCount,
			layout: layout
		)
		self.minRows = rowFactory.min
		self.maxRows = rowFactory.max
		self.cells = cells
		self.measurements = Array(
			repeating: nil,
			count: cells.count
		)
	}

	public struct GridMetrics {
		public let columns: TrackLayout
		public let rows: TrackLayout
		public let measured: [CGSize]

		public init(
			columns: TrackLayout,
			rows: TrackLayout,
			measured: [CGSize]
		) {
			self.columns = columns
			self.rows = rows
			self.measured = measured
		}

		public var size: CGSize {
			.init(width: columns.size, height: rows.size)
		}
	}

	public func calculate(bounds: CGSize) -> GridMetrics {
		columns.apply(
			available: bounds.width,
			intrinsic: intrinsicColumnWidth
		)
		measureElementsForResolvedColumns()
		rows.apply(
			available: bounds.height,
			intrinsic: intrinsicRowHeight
		)
		return GridMetrics(
			columns: columns,
			rows: rows,
			measured: measurements.map { $0?.size ?? .zero }
		)
	}

	public func measuredSize(at index: Int) -> CGSize? {
		guard measurements.indices.contains(index) else {
			return nil
		}
		return measurements[index]?.size
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
			width = max(width, size.width)
		}
		return width
	}

	private func measureElementsForResolvedColumns() {
		for column in 0..<columnCount {
			let width = columns.lengths[column]
			let resolvedBounds = CGSize(width: width, height: .unbounded)
			for row in 0..<rowCount {
				let index = cellIdx(column, row)
				guard index < cellCount else {
					continue
				}
				guard width > 0 else {
					measurements[index] = Measurement(
						bounds: resolvedBounds,
						size: .zero
					)
					continue
				}
				if canReuseIntrinsicMeasurement(
					at: index,
					resolvedWidth: width
				) {
					continue
				}
				_ = measureElement(
					at: index,
					bounds: resolvedBounds
				)
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
			height = max(
				height,
				measurements[index]?.size.height ?? 0
			)
		}
		return height
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
		measurements[index] = Measurement(
			bounds: bounds,
			size: size
		)
		return size
	}
}
