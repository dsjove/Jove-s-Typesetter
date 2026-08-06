import CoreGraphics
// TODO: Feature - Pagination policies
// TODO: Feature - Pivot Table
// TODO: Feature - Wrapping
//     wrapped(v) - hits bottom, sets y = 0 and x+=width, measured width needs to account
//     wrapped(h) - hits right, sets x = 0 and y+=height, measured height needs to account
//     header duplication?
// TODO: Feature - identifiable reducers and groupings for uniform tracks

// Remaining Custom Columns...
// TODO: Feature - column-header/row-leader (track property) spans
// TODO: Feature - dynamic gaps that fill (like SwiftUI spacer)
// TODO: Feature - 'best fit' intrinsic size (allow 3, algorithm TBD)
// TODO: Not Needed - Identifiable and Hashable cells for optimized measurements recompute
// TODO: Not Needed - Split/StickyCol tables (independantly scrollable areas)

public extension Grid {
//MARK: Convenience inits
	init(
		horzFlow col: Column, wrapped at: Int? = nil,
		rows: Rows = .init(align: .left),
		@JCSLayoutElementBuilder cells: ()->Cells,
		render: ((ColumnIteration)->())? = nil,
	) {
		let cells = cells()
		self.init(
			cols: .init(Array(repeating: col, count: at ?? cells.count)),
			rows: rows,
			render: .init(column: render),
			cells: cells)
	}

	init(
		vertFlow col: Column,
		rows: Rows = .init(align: .centerY),
		@JCSLayoutElementBuilder cells: ()->Cells,
		render: ((RowIteration)->())? = nil
	) {
		let cells = cells()
		self.init(
			cols: .init(col: col),
			rows: rows,
			render: .init(row: render),
			cells: cells)
	}

	init(
		table cols: [Column], columnMap: ((Int)->Int)? = nil,
		header: Track? = nil,
		leader: Track? = nil,
		rows: TrackFactory = .init(),
		@JCSLayoutElementBuilder cells: ()->Cells,
		rowRender: ((RowIteration)->())? = nil,
		colRender: ((ColumnIteration)->())? = nil,
		cellRender: ((CellIteration)->())? = nil
	) {
		let cells = cells()
		let cols = {
			if let leader {
				[leader] + cols
			} else {
				cols
			}
		}()
		self.init(
			cols: .init(cols, map: columnMap),
			rows: .init(
				minCount: rows.minCount,
				maxCount: rows.maxCount,
				def: { if let header, $0 == 0 { header } else { rows.def($0) } }
			),
			render: .init(column: colRender, row: rowRender, cell: cellRender),
			cells: cells)
	}
}

public extension GridDefinition<TrackedElement>.CellIteration {
	func render() {
		cell?.element.draw(in: rect, measured: content, align: alignment)
//JCSRect(fill: .clear, stroke: .red , lineWidth: 0.5, radius: 0).draw(in: rect)
	}
}

public struct Grid: JCSLayoutElement {
//MARK: Types
	public typealias Layout = GridLayout<TrackedElement>
	public typealias Definition = GridDefinition<TrackedElement>
	public typealias Column = Track
	public typealias Columns = TrackFactory
	public typealias Row = Track
	public typealias Rows = TrackFactory
	public typealias Cell = JCSLayoutElement
	public typealias Cells = [JCSLayoutElement]

	public typealias ColumnIteration = Definition.ColumnIteration
	public typealias RowIteration = Definition.RowIteration
	public typealias CellIteration = Definition.CellIteration

	public struct Render {
		public let column: ((ColumnIteration)->())?
		public let row: ((RowIteration)->())?
		public let cell: (CellIteration)->()

		public init(
			column: ((ColumnIteration) -> ())? = nil,
			row: ((RowIteration) -> ())? = nil,
			cell: ((CellIteration) -> ())? = nil
		) {
			self.column = column
			self.row = row
			self.cell = {
				if let cell { cell($0) } else { $0.render() }
			}
		}
	}

//MARK: Inits
	public init(
		cols: Columns,
		rows: Rows = .init(),
		render: Render = .init(),
		arrangement: TrackArrangement = .gaps,
		@JCSLayoutElementBuilder cells: ()->Cells
	) {
		self.init(
			cols: cols,
			rows: rows,
			render: render,
			arrangement: arrangement,
			cells: cells())
	}

	public init(
		cols: Columns,
		rows: Rows = .init(),
		render: Render = .init(),
		arrangement: TrackArrangement = .gaps,
		cells: Cells
	) {
		self.render = render
		self.layout = .init(
			columns: cols,
			rows: rows,
			cells: cells.map(TrackedElement.init),
			arrangement: arrangement)
	}

	public private(set) var id: String = ""

	public func id(_ id: String) -> Self {
		var copy = self
		copy.id = id
		return copy
	}

//MARK: API
	public let layout: Layout
	public let render: Render

	public func measure(bounds: CGSize) -> CGSize {
		let definition = layout.measure(bounds: bounds)
		return definition.size
	}

	public func draw(in allocated: CGRect, measured: CGSize, align: Alignment) {
		let definition = layout.measure(bounds: measured)
		let positioned = align.apply(size: definition.size, in: allocated)
//JCSRect(fill: .clear, stroke: .blue.withAlphaComponent(0.5) , lineWidth: 1.5, radius: 0).draw(in: positioned)
		definition.iterate(
			allocated: positioned,
			column: render.column,
			row: render.row,
			cell: render.cell
		)
	}
}
