import CoreGraphics
// TODO: Feature - Pagination policies
// TODO: Feature - Pivot Table
// TODO: Feature - column spans and column mapping (CustomColumns)
// TODO: Feature - Wrapping
//     wrapped(v) - hits bottom, sets y = 0 and x+=width, measured width needs to account
//     wrapped(h) - hits right, sets x = 0 and y+=height, measured height needs to account
// TODO: Bug - Grid is a value type but copies share this mutable Layout. Copy-on-write

public extension Grid {
//MARK: Convenience inits
	init(
		horzFlow col: Column,
		rows: Rows = .init(align: .left),
		render: ((ColumnIteration)->())? = nil,
		@JCSLayoutElementBuilder cells: ()->Cells
	) {
		let cells = cells()
		self.init(
			cols: Array(repeating: col, count: cells.count),
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
			cols: [col],
			rows: rows,
			render: .init(row: render),
			cells: cells)
	}

	init(
		table: Columns,
		header: Track? = nil,
		rows: TrackFactory = .init(),
		@JCSLayoutElementBuilder cells: ()->Cells,
		render: ((RowIteration)->())? = nil
	) {
		let cells = cells()
		self.init(
			cols: table,
			rows: .init(
				min: rows.min,
				max: rows.max,
				def: { if let header, $0 == 0 { header } else { rows.def($0) } }
			),
			render: .init(row: render),
			cells: cells)
	}
}

public extension GridLayout.CellIteration where GridLayout.Cell == TrackedElement {
	func render() {
		cell?.element.draw(in: rect, measured: content, align: alignment);
	}
}

public struct Grid: JCSLayoutElement {
//MARK: Types
	public typealias Layout = GridLayout<TrackedElement>
	public typealias Column = Track
	public typealias Columns = [Column]
	public typealias Row = Track
	public typealias Rows = TrackFactory
	public typealias Cell = JCSLayoutElement
	public typealias Cells = [JCSLayoutElement]

	public typealias ColumnIteration = Layout.ColumnIteration
	public typealias RowIteration = Layout.RowIteration
	public typealias CellIteration = Layout.CellIteration

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
				JCSRect(fill: .clear, stroke: .red.withAlphaComponent(0.25), lineWidth: 0.5, radius: 0.0).draw(in: $0.rect)
			}
		}
	}

//MARK: Inits
	public init(
		cols: Columns,
		rows: Rows = .init(),
		render: Render = .init(),
		@JCSLayoutElementBuilder cells: ()->Cells
	) {
		self.init(
			cols: cols,
			rows: rows,
			render: render,
			cells: cells())
	}

	// Row/Column sorting should happen outside the Grid.
	// This is not a reactive grid where columns/rows/cells have identity.
	public init(
		cols: Columns,
		rows: Rows = .init(),
		render: Render = .init(),
		cells: Cells,
		layout: TrackArrangement = .gaps
	) {
		self.render = render
		self.layout = .init(
			columns: cols,
			rows: rows,
			cells: cells.map(TrackedElement.init),
			layout: layout)
	}

//MARK: API
	public let layout: Layout
	public let render: Render

	public private(set) var id : String = ""
	public func id(_ id: String) -> Self {
		var copy = self
		copy.id = id
		return copy
	}

	public func measure(bounds: CGSize) -> CGSize {
		layout.measure(bounds: bounds).size
	}

	public func draw(in allocated: CGRect, measured: CGSize, align: Alignment) {
		let metrics = layout.measure(bounds: measured)
		let positioned = align.apply(size: metrics.size, in: allocated)

		JCSRect(
			fill: .clear,
			stroke: .blue,
			lineWidth: 1.5,
			radius: 0).draw(in: allocated)

		layout.iterate(
			metrics: metrics,
			allocated: positioned,
			column: render.column,
			row: render.row,
			cell: render.cell
		)
	}
}
