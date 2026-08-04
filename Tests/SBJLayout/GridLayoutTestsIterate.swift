import CoreGraphics
import Testing
@testable import Jove_s_Typesetter

@Suite("GridLayout iteration")
struct GridLayoutIterationTests {
	private final class MeasuringElement: TrackElement {
		private(set) var measuredBounds: [CGSize] = []
		let measureBlock: (CGSize) -> CGSize

		init(
			size: CGSize
		) {
			self.measureBlock = { _ in size }
		}

		init(
			measure: @escaping (CGSize) -> CGSize
		) {
			self.measureBlock = measure
		}

		func measure(bounds: CGSize) -> CGSize {
			measuredBounds.append(bounds)
			return measureBlock(bounds)
		}

		var measureCount: Int {
			measuredBounds.count
		}
	}

	@Test("Default row count matches the cells required")
	func defaultRowCountMatchesWantedRows() {
		let cells = (0..<5).map { _ in
			MeasuringElement(size: CGSize(width: 10, height: 10))
		}
		let grid = GridLayout(
			columns: [
				Track(.fixed(20)),
				Track(.fixed(20))
			],
			cells: cells,
			layout: .tight
		)

		#expect(grid.wantedRowCount == 3)
		#expect(grid.rowCount == 3)
		#expect(grid.rows.count == 3)
	}

	@Test("Minimum rows can add empty rows")
	func minimumRowsAddsEmptyRows() {
		let cell = MeasuringElement(
			size: CGSize(width: 10, height: 7)
		)
		let rows = TrackFactory(
			min: 3,
			max: 5,
			Track(.intrinsic())
		)
		let grid = GridLayout(
			columns: [Track(.fixed(20))],
			rows: rows,
			cells: [cell],
			layout: .tight
		)

		let result = grid.measure(bounds: .unbounded)

		#expect(grid.rowCount == 3)
		#expect(grid.rows.count == 3)
		#expect(result.rows.lengths == [7, 0, 0])
		#expect(result.size == CGSize(width: 20, height: 7))
		#expect(cell.measureCount == 1)
	}

	@Test("Maximum rows truncates excess cells")
	func maximumRowsTruncatesExcessCells() {
		let cells = (0..<5).map { _ in
			MeasuringElement(size: CGSize(width: 10, height: 10))
		}
		let rows = TrackFactory(
			min: 0,
			max: 2,
			Track(.intrinsic())
		)
		let grid = GridLayout(
			columns: [
				Track(.fixed(20)),
				Track(.fixed(20))
			],
			rows: rows,
			cells: cells,
			layout: .tight
		)

		_ = grid.measure(bounds: .unbounded)

		#expect(grid.wantedRowCount == 3)
		#expect(grid.rowCount == 2)
		#expect(grid.rows.count == 2)
		#expect(grid.cellCount == 4)
		#expect(cells[0].measureCount == 1)
		#expect(cells[1].measureCount == 1)
		#expect(cells[2].measureCount == 1)
		#expect(cells[3].measureCount == 1)
		#expect(cells[4].measureCount == 0)
	}

	@Test("An unconstrained intrinsic cell is measured only once")
	func intrinsicCellIsMeasuredOnce() {
		let cell = MeasuringElement(
			size: CGSize(width: 40, height: 12)
		)
		let grid = GridLayout(
			columns: [Track(.intrinsic())],
			cells: [cell],
			layout: .tight
		)

		let result = grid.measure(bounds: .unbounded)

		#expect(result.columns.lengths == [40])
		#expect(result.rows.lengths == [12])
		#expect(result.measured == [CGSize(width: 40, height: 12)])
		#expect(cell.measureCount == 1)
		#expect(cell.measuredBounds == [.unbounded])
	}

	@Test("A fixed-width cell is measured once and reused")
	func fixedCellMeasurementIsCached() {
		let cell = MeasuringElement { bounds in
			CGSize(width: bounds.width, height: 14)
		}
		let grid = GridLayout(
			columns: [Track(.fixed(80))],
			cells: [cell],
			layout: .tight
		)

		let first = grid.measure(
			bounds: CGSize(width: 200, height: .unbounded)
		)
		let second = grid.measure(
			bounds: CGSize(width: 200, height: .unbounded)
		)

		#expect(first.measured == [CGSize(width: 80, height: 14)])
		#expect(second.measured == first.measured)
		#expect(cell.measureCount == 1)
		#expect(
			cell.measuredBounds == [
				CGSize(width: 80, height: .unbounded)
			]
		)
	}

	@Test("A fill cell is remeasured only when its resolved width changes")
	func fillCellRemeasuresForChangedWidth() {
		let cell = MeasuringElement { bounds in
			CGSize(width: bounds.width, height: bounds.width / 10)
		}
		let grid = GridLayout(
			columns: [Track(.fill())],
			cells: [cell],
			layout: .tight
		)

		let first = grid.measure(
			bounds: CGSize(width: 100, height: .unbounded)
		)
		let repeated = grid.measure(
			bounds: CGSize(width: 100, height: .unbounded)
		)
		let changed = grid.measure(
			bounds: CGSize(width: 150, height: .unbounded)
		)

		#expect(first.measured == [CGSize(width: 100, height: 10)])
		#expect(repeated.measured == first.measured)
		#expect(changed.measured == [CGSize(width: 150, height: 15)])
		#expect(cell.measureCount == 2)
		#expect(
			cell.measuredBounds == [
				CGSize(width: 100, height: .unbounded),
				CGSize(width: 150, height: .unbounded)
			]
		)
	}

	@Test("Rows use cached cell heights without measuring again")
	func rowCalculationUsesCachedMeasurements() {
		let first = MeasuringElement(
			size: CGSize(width: 20, height: 8)
		)
		let second = MeasuringElement(
			size: CGSize(width: 30, height: 15)
		)
		let grid = GridLayout(
			columns: [
				Track(.fixed(40)),
				Track(.fixed(40))
			],
			cells: [first, second],
			layout: .tight
		)

		let result = grid.measure(bounds: .unbounded)

		#expect(result.rows.lengths == [15])
		#expect(first.measureCount == 1)
		#expect(second.measureCount == 1)
	}

	@Test("Grid metrics combine track lengths, gaps, and offsets")
	func metricsContainResolvedTracks() {
		let cells = (0..<4).map { index in
			MeasuringElement(
				size: CGSize(
					width: 5,
					height: CGFloat(index + 1)
				)
			)
		}
		let rows = TrackFactory(
			min: 2,
			max: 2,
			Track(.fixed(10), gap: 3)
		)
		let grid = GridLayout(
			columns: [
				Track(.fixed(20), gap: 5),
				Track(.fixed(30), gap: 9)
			],
			rows: rows,
			cells: cells,
			layout: .gaps
		)

		let result = grid.measure(bounds: .unbounded)

		#expect(result.columns.lengths == [20, 30])
		#expect(result.columns.offsets == [0, 25])
		#expect(result.columns.size == 55)
		#expect(result.rows.lengths == [10, 10])
		#expect(result.rows.offsets == [0, 13])
		#expect(result.rows.size == 23)
		#expect(result.size == CGSize(width: 55, height: 23))
	}

	@Test("Empty columns produce an empty grid without measuring cells")
	func emptyColumnsProduceEmptyGrid() {
		let cell = MeasuringElement(
			size: CGSize(width: 10, height: 10)
		)
		let grid = GridLayout(
			columns: [],
			cells: [cell],
			layout: .tight
		)

		let result = grid.measure(bounds: .unbounded)

		#expect(grid.isEmpty)
		#expect(grid.columnCount == 0)
		#expect(grid.rowCount == 0)
		#expect(grid.cellCount == 0)
		#expect(result.size == .zero)
		#expect(result.measured == [.zero])
		#expect(cell.measureCount == 0)
	}

	@Test("Cell indexing is row-major")
	func cellIndexingIsRowMajor() {
		let cells = (0..<6).map { _ in
			MeasuringElement(size: .zero)
		}
		let grid = GridLayout(
			columns: [
				Track(.fixed(1)),
				Track(.fixed(1)),
				Track(.fixed(1))
			],
			cells: cells,
			layout: .tight
		)

		#expect(grid.cellIdx(0, 0) == 0)
		#expect(grid.cellIdx(2, 0) == 2)
		#expect(grid.cellIdx(0, 1) == 3)
		#expect(grid.cellIdx(2, 1) == 5)
	}


	@Test("Iterate emits columns, rows, and cells in row-major order")
	func iterateEmitsExpectedMetadataAndRects() {
		let cells = (0..<4).map { index in
			MeasuringElement(
				size: CGSize(width: CGFloat(index + 1), height: CGFloat(index + 2))
			)
		}
		let rows = TrackFactory(
			min: 2,
			max: 2,
			Track(.fixed(10), align: .bottom, gap: 3)
		)
		let grid = GridLayout(
			columns: [
				Track(.fixed(20), align: .left, gap: 5),
				Track(.fixed(30), align: .right, gap: 7)
			],
			rows: rows,
			cells: cells,
			layout: .gaps
		)

		let metrics = grid.measure(bounds: .unbounded)

		var columnIterations: [GridLayout<MeasuringElement>.ColumnIteration] = []
		var rowIterations: [GridLayout<MeasuringElement>.RowIteration] = []
		var cellIterations: [GridLayout<MeasuringElement>.CellIteration] = []

		grid.iterate(
			metrics: metrics,
			allocated: CGRect(x: 100, y: 200, width: 500, height: 500),
			column: { columnIterations.append($0) },
			row: { rowIterations.append($0) },
			cell: { cellIterations.append($0) }
		)

		#expect(columnIterations.map(\.index) == [0, 1])
		#expect(columnIterations.map(\.rect) == [
			CGRect(x: 100, y: 200, width: 20, height: 23),
			CGRect(x: 125, y: 200, width: 30, height: 23)
		])
		#expect(rowIterations.map(\.index) == [0, 1])
		#expect(rowIterations.map(\.rect) == [
			CGRect(x: 100, y: 200, width: 55, height: 10),
			CGRect(x: 100, y: 213, width: 55, height: 10)
		])
		#expect(cellIterations.map(\.i) == [0, 1, 2, 3])
		#expect(cellIterations.map(\.c) == [0, 1, 0, 1])
		#expect(cellIterations.map(\.r) == [0, 0, 1, 1])
		#expect(cellIterations.map(\.rect) == [
			CGRect(x: 100, y: 200, width: 20, height: 10),
			CGRect(x: 125, y: 200, width: 30, height: 10),
			CGRect(x: 100, y: 213, width: 20, height: 10),
			CGRect(x: 125, y: 213, width: 30, height: 10)
		])
		#expect(cellIterations.map(\.content) == cells.map { Optional($0.measureBlock(.zero)) })
		#expect(cellIterations[0].alignment == [.left, .bottom])
		#expect(cellIterations[1].alignment == [.right, .bottom])
	}

	@Test("Iterate permits cell-only callbacks")
	func iteratePermitsCellOnlyCallbacks() {
		let cell = MeasuringElement(size: CGSize(width: 5, height: 6))
		let grid = GridLayout(
			columns: [Track(.fixed(20))],
			cells: [cell],
			layout: .tight
		)
		let metrics = grid.measure(bounds: .unbounded)

		var iterations: [GridLayout<MeasuringElement>.CellIteration] = []
		grid.iterate(metrics: metrics) { iterations.append($0) }

		#expect(iterations.count == 1)
		#expect(iterations[0].i == 0)
		#expect(iterations[0].cell === cell)
		#expect(iterations[0].content == CGSize(width: 5, height: 6))
		#expect(iterations[0].rect == CGRect(x: 0, y: 0, width: 20, height: 6))
	}

	@Test("Iterate reports nil for an empty trailing grid cell")
	func iterateReportsEmptyTrailingCell() {
		let cells = (0..<3).map { _ in
			MeasuringElement(size: CGSize(width: 5, height: 8))
		}
		let rows = TrackFactory(
			min: 2,
			max: 2,
			Track(.fixed(10))
		)
		let grid = GridLayout(
			columns: [Track(.fixed(20)), Track(.fixed(20))],
			rows: rows,
			cells: cells,
			layout: .tight
		)
		let metrics = grid.measure(bounds: .unbounded)

		var iterations: [GridLayout<MeasuringElement>.CellIteration] = []
		grid.iterate(metrics: metrics) { iterations.append($0) }

		#expect(iterations.map(\.i) == [0, 1, 2, 3])
		#expect(iterations[0].cell === cells[0])
		#expect(iterations[1].cell === cells[1])
		#expect(iterations[2].cell === cells[2])
		#expect(iterations[3].cell == nil)
		#expect(iterations[3].content == nil)
		#expect(iterations[3].rect == CGRect(x: 20, y: 10, width: 20, height: 10))
	}

	@Test("Truncate true excludes partially clipped columns and cells")
	func iterateTruncateTrueRequiresFullHorizontalFit() {
		let cells = [
			MeasuringElement(size: CGSize(width: 5, height: 10)),
			MeasuringElement(size: CGSize(width: 5, height: 10))
		]
		let grid = GridLayout(
			columns: [
				Track(.fixed(20), gap: 5),
				Track(.fixed(30))
			],
			cells: cells,
			layout: .gaps
		)
		let metrics = grid.measure(bounds: .unbounded)

		var columns: [Int] = []
		var cellIndexes: [Int] = []
		grid.iterate(
			metrics: metrics,
			allocated: CGRect(x: 0, y: 0, width: 40, height: 20),
			truncate: true,
			column: { columns.append($0.index) },
			cell: { cellIndexes.append($0.i) }
		)

		#expect(columns == [0])
		#expect(cellIndexes == [0])
	}

	@Test("Truncate false includes tracks whose origin is inside the allocation")
	func iterateTruncateFalsePermitsPartialHorizontalFit() {
		let cells = [
			MeasuringElement(size: CGSize(width: 5, height: 10)),
			MeasuringElement(size: CGSize(width: 5, height: 10))
		]
		let grid = GridLayout(
			columns: [
				Track(.fixed(20), gap: 5),
				Track(.fixed(30))
			],
			cells: cells,
			layout: .gaps
		)
		let metrics = grid.measure(bounds: .unbounded)

		var columns: [Int] = []
		var cellIndexes: [Int] = []
		grid.iterate(
			metrics: metrics,
			allocated: CGRect(x: 0, y: 0, width: 40, height: 20),
			truncate: false,
			column: { columns.append($0.index) },
			cell: { cellIndexes.append($0.i) }
		)

		#expect(columns == [0, 1])
		#expect(cellIndexes == [0, 1])
	}

	@Test("Vertical truncation uses the allocated maximum Y")
	func iterateUsesMaximumYForRowTruncation() {
		let cells = [
			MeasuringElement(size: CGSize(width: 5, height: 5)),
			MeasuringElement(size: CGSize(width: 5, height: 5))
		]
		let rows = TrackFactory(
			min: 2,
			max: 2,
			Track(.fixed(10), gap: 3)
		)
		let grid = GridLayout(
			columns: [Track(.fixed(20))],
			rows: rows,
			cells: cells,
			layout: .gaps
		)
		let metrics = grid.measure(bounds: .unbounded)

		var rowIndexes: [Int] = []
		var cellIndexes: [Int] = []
		grid.iterate(
			metrics: metrics,
			allocated: CGRect(x: 100, y: 200, width: 20, height: 18),
			truncate: true,
			row: { rowIndexes.append($0.index) },
			cell: { cellIndexes.append($0.i) }
		)

		#expect(rowIndexes == [0])
		#expect(cellIndexes == [0])
	}

    @Test("Iterate uses the supplied metrics snapshot after a later measurement")
    func iterateUsesSuppliedMetricsSnapshot() {
        let cell = MeasuringElement { bounds in
            CGSize(width: bounds.width, height: bounds.width / 10)
        }
        let grid = GridLayout(
            columns: [Track(.fill())],
            cells: [cell],
            layout: .tight
        )

        let first = grid.measure(
            bounds: CGSize(width: 100, height: .unbounded)
        )
        _ = grid.measure(
            bounds: CGSize(width: 150, height: .unbounded)
        )

        var iterations: [GridLayout<MeasuringElement>.CellIteration] = []
        grid.iterate(
            metrics: first,
            allocated: CGRect(x: 25, y: 35, width: 100, height: 10),
            cell: { iterations.append($0) }
        )

        #expect(iterations.count == 1)
        #expect(iterations[0].metrics.size == CGSize(width: 100, height: 10))
        #expect(iterations[0].rect == CGRect(x: 25, y: 35, width: 100, height: 10))
        #expect(iterations[0].content == CGSize(width: 100, height: 10))
    }

}
