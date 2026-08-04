import CoreGraphics
import Testing
@testable import SBJLayout

@Suite("GridLayout")
struct GridLayoutTests {
	private final class MeasuringElement: TrackElement {
		private(set) var measuredBounds: [CGSize] = []
		let measureBlock: (CGSize) -> CGSize

		init(size: CGSize) {
			self.measureBlock = { _ in size }
		}

		init(measure: @escaping (CGSize) -> CGSize) {
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

	@Test("An unconstrained intrinsic cell is measured only once")
	func intrinsicCellIsMeasuredOnce() {
		let cell = MeasuringElement(
			size: CGSize(width: 40, height: 12)
		)
		let layout = GridLayout(
			columns: [Track(.intrinsic())],
			cells: [cell],
			layout: .tight
		)

		let definition = layout.measure(bounds: .unbounded)

		#expect(definition.columns.lengths == [40])
		#expect(definition.rows.lengths == [12])
		#expect(definition.measured == [CGSize(width: 40, height: 12)])
		#expect(cell.measureCount == 1)
		#expect(cell.measuredBounds == [.unbounded])
	}

	@Test("A fixed-width cell measurement is reused")
	func fixedCellMeasurementIsCached() {
		let cell = MeasuringElement { bounds in
			CGSize(width: bounds.width, height: 14)
		}
		let layout = GridLayout(
			columns: [Track(.fixed(80))],
			cells: [cell],
			layout: .tight
		)

		let first = layout.measure(
			bounds: CGSize(width: 200, height: .unbounded)
		)
		let second = layout.measure(
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
		let layout = GridLayout(
			columns: [Track(.fill())],
			cells: [cell],
			layout: .tight
		)

		let first = layout.measure(
			bounds: CGSize(width: 100, height: .unbounded)
		)
		let repeated = layout.measure(
			bounds: CGSize(width: 100, height: .unbounded)
		)
		let changed = layout.measure(
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

	@Test("Row calculation reuses cached cell measurements")
	func rowCalculationUsesCachedMeasurements() {
		let first = MeasuringElement(
			size: CGSize(width: 20, height: 8)
		)
		let second = MeasuringElement(
			size: CGSize(width: 30, height: 15)
		)
		let layout = GridLayout(
			columns: [
				Track(.fixed(40)),
				Track(.fixed(40))
			],
			cells: [first, second],
			layout: .tight
		)

		let definition = layout.measure(bounds: .unbounded)

		#expect(definition.rows.lengths == [15])
		#expect(first.measureCount == 1)
		#expect(second.measureCount == 1)
	}

	@Test("Changed cell measurements invalidate resolved row heights")
	func changedMeasurementsInvalidateRows() {
		let cell = MeasuringElement { bounds in
			CGSize(width: bounds.width, height: bounds.width / 5)
		}
		let layout = GridLayout(
			columns: [Track(.fill())],
			rows: .init(Track(.intrinsic())),
			cells: [cell],
			layout: .tight
		)

		let first = layout.measure(
			bounds: CGSize(width: 50, height: .unbounded)
		)
		let second = layout.measure(
			bounds: CGSize(width: 100, height: .unbounded)
		)

		#expect(first.rows.lengths == [10])
		#expect(second.rows.lengths == [20])
		#expect(cell.measureCount == 2)
	}

	@Test("Zero-width resolved columns cache zero without measuring the cell")
	func zeroWidthColumnDoesNotMeasureCell() {
		let cell = MeasuringElement(
			size: CGSize(width: 10, height: 10)
		)
		let layout = GridLayout(
			columns: [Track(.fixed(0))],
			cells: [cell],
			layout: .tight
		)

		let definition = layout.measure(bounds: .unbounded)

		#expect(definition.measured == [.zero])
		#expect(definition.rows.lengths == [0])
		#expect(cell.measureCount == 0)
	}

	@Test("Measure publishes the latest definition while preserving earlier snapshots")
	func measurePublishesLatestImmutableDefinition() {
		let cell = MeasuringElement { bounds in
			CGSize(width: bounds.width, height: bounds.width / 10)
		}
		let layout = GridLayout(
			columns: [Track(.fill())],
			cells: [cell],
			layout: .tight
		)

		let first = layout.measure(
			bounds: CGSize(width: 100, height: .unbounded)
		)
		let second = layout.measure(
			bounds: CGSize(width: 150, height: .unbounded)
		)

		#expect(first.bounds == CGSize(width: 100, height: .unbounded))
		#expect(first.size == CGSize(width: 100, height: 10))
		#expect(first.measured == [CGSize(width: 100, height: 10)])

		#expect(second.bounds == CGSize(width: 150, height: .unbounded))
		#expect(second.size == CGSize(width: 150, height: 15))
		#expect(second.measured == [CGSize(width: 150, height: 15)])

		#expect(layout.definition.bounds == second.bounds)
		#expect(layout.definition.size == second.size)
		#expect(layout.definition.measured == second.measured)
	}


	@Test("Maximum rows prevent excluded cells from being measured")
	func maximumRowsExcludeMeasurements() {
		let cells = (0..<5).map { _ in
			MeasuringElement(size: CGSize(width: 10, height: 10))
		}
		let layout = GridLayout(
			columns: [
				Track(.fixed(20)),
				Track(.fixed(20))
			],
			rows: .init(
				min: 0,
				max: 2,
				Track(.intrinsic())
			),
			cells: cells,
			layout: .tight
		)

		_ = layout.measure(bounds: .unbounded)

		#expect(cells[0].measureCount == 1)
		#expect(cells[1].measureCount == 1)
		#expect(cells[2].measureCount == 1)
		#expect(cells[3].measureCount == 1)
		#expect(cells[4].measureCount == 0)
	}

	@Test("Empty columns do not measure cells")
	func emptyColumnsDoNotMeasureCells() {
		let cell = MeasuringElement(
			size: CGSize(width: 10, height: 10)
		)
		let layout = GridLayout(
			columns: [],
			cells: [cell],
			layout: .tight
		)

		let definition = layout.measure(bounds: .unbounded)

		#expect(definition.size == .zero)
		#expect(definition.measured == [.zero])
		#expect(cell.measureCount == 0)
	}

	@Test("An intrinsic column uses its widest visible cell")
	func intrinsicColumnUsesWidestCell() {
		let cells = [
			MeasuringElement(size: CGSize(width: 20, height: 5)),
			MeasuringElement(size: CGSize(width: 45, height: 6)),
			MeasuringElement(size: CGSize(width: 30, height: 7))
		]
		let layout = GridLayout(
			columns: [Track(.intrinsic())],
			cells: cells,
			layout: .tight
		)

		let definition = layout.measure(bounds: .unbounded)

		#expect(definition.columns.lengths == [45])
		#expect(cells.map(\.measureCount) == [2, 1, 2])

		#expect(cells[0].measuredBounds == [
			.unbounded,
			CGSize(width: 45, height: .unbounded)
		])
		#expect(cells[1].measuredBounds == [
			.unbounded
		])
		#expect(cells[2].measuredBounds == [
			.unbounded,
			CGSize(width: 45, height: .unbounded)
		])
	}

}
