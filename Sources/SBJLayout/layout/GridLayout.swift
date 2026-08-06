import CoreGraphics

public final class GridLayout<Element: TrackElement> {
	public typealias Cell = Element
	public typealias Definition = GridDefinition<Cell>
	public typealias TrackIteration = Definition.TrackIteration
	public typealias ColumnIteration = Definition.ColumnIteration
	public typealias RowIteration = Definition.RowIteration
	public typealias CellIteration = Definition.CellIteration

	public private(set) var definition: Definition
	private let columns: TrackLayout
	private let rows: TrackLayout

	private struct Measurement {
		let bounds: CGSize
		let size: CGSize
	}
	private var measurements: [Measurement?]
	private var measurementRevision: UInt = 0

	public init(
		columns: TrackFactory,
		rows: TrackFactory = .init(),
		cells: [Element],
		arrangement: TrackArrangement = .gaps
	) {
		let definition = Definition(
			columns: columns,
			rows: rows,
			cells: cells,
			arrangement: arrangement
		)
		self.definition = definition
		self.columns = definition.columnLayout
		self.rows = definition.rowLayout
		self.measurements = Array(repeating: nil, count: definition.cells.count)
	}

	public func measure(bounds: CGSize) -> Definition {
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
		definition = definition.resolving(
			bounds: bounds,
			columns: columns.metrics,
			rows: rows.metrics,
			measured: measurements.map { $0?.size ?? .zero }
		)
		return definition
	}

	private func intrinsicColumnWidth(_ column: Int, _ track: Track, _ bound: CGFloat) -> CGFloat {
		let reduce = track.aggregate
		var acc: CGFloat? = nil
		definition.forEachCell(inColumn: column) { index in
			let candidate = measureElement(at: index, bounds: CGSize(width: bound, height: .unbounded)).width
			if let current = acc{
				acc = reduce(current, candidate)
			} else {
				acc = candidate
			}
		}
		return acc ?? 0
	}

	private func measureElementsForResolvedColumns() {
		for column in 0..<definition.columnCount {
			guard columns.lengths.indices.contains(column) else { continue }
			let width = columns.lengths[column]
			let resolvedBounds = CGSize(width: width, height: .unbounded)

			definition.forEachCell(inColumn: column) { index in
				guard width > 0 else {
					setMeasurement(at: index, Measurement(bounds: resolvedBounds, size: .zero))
					return
				}
				if canReuseIntrinsicMeasurement(at: index, resolvedWidth: width) {
					return
				}
				measureElement(at: index, bounds: resolvedBounds)
			}
		}
	}

	private func intrinsicRowHeight(_ row: Int, track: Track, _ bound: CGFloat) -> CGFloat {
		let reduce = track.aggregate
		var acc: CGFloat? = nil
		definition.forEachCell(inRow: row) { index in
			let candidate = measurements[index]?.size.height
			if let current = acc, let candidate {
				acc = reduce(current, candidate)
			} else {
				acc = candidate
			}
		}
		return acc ?? 0
	}

	private func canReuseIntrinsicMeasurement(at index: Int, resolvedWidth: CGFloat) -> Bool {
		guard let cached = measurements[index] else { return false }
		return cached.bounds.width == .unbounded
			&& cached.bounds.height == .unbounded
			&& cached.size.width == resolvedWidth
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
	private func measureElement(at index: Int, bounds: CGSize) -> CGSize {
		guard definition.cells.indices.contains(index) else { return .zero }
		if let cached = measurements[index], cached.bounds == bounds {
			return cached.size
		}
		let size = definition.cells[index].measure(bounds: bounds)
		setMeasurement(
			at: index,
			Measurement(bounds: bounds, size: size)
		)
		return size
	}
}

