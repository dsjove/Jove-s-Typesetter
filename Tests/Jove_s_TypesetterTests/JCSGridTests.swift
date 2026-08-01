import CoreGraphics
import Testing
@testable import Jove_s_Typesetter

@Suite("JCSGrid dimension application")
struct JCSGridTests {
	private final class TestCell: JCSLayoutElement {
		let naturalSize: CGSize
		private(set) var measuredBounds: [CGSize] = []

		init(_ width: CGFloat, _ height: CGFloat = 10) {
			self.naturalSize = CGSize(width: width, height: height)
		}

		func measure(bounds: CGSize) -> CGSize {
			measuredBounds.append(bounds)

			let width = bounds.width.isUnbounded
				? naturalSize.width
				: min(naturalSize.width, max(bounds.width, 0))

			return CGSize(width: width, height: naturalSize.height)
		}

		func draw(in allocated: CGRect, measured: CGSize, align: JCSAlignment) {}
	}

	private func specification(
		widths: [JCSDimension],
		columnGap: CGFloat = 20,
		rowHeight: JCSDimension = .intrinsic(),
		rowGap: CGFloat = 0,
		cells: [TestCell],
		render: JCSGrid.Render = .init()
	) -> JCSGrid.Specification {
		.init(
			cols: widths.map {
				.init($0, gap: columnGap)
			},
			rows: .init(def: { _ in
				.init(rowHeight, gap: rowGap)
			}),
			cells: cells,
			render: render
		)
	}

	@Test("Intrinsic followed by fill has one gap")
	func intrinsicThenFill() {
		let spec = specification(
			widths: [.intrinsic(), .fill()],
			cells: [TestCell(80), TestCell(500)]
		)

		let layout = spec.calculateLayout(spec.prepare(), for: CGSize(width: 300, height: .unbounded))

		#expect(layout.columnWidths == [80, 200])
		#expect(layout.columnOffsets == [0, 100])
		#expect(layout.size.width == 300)
	}

	@Test("Three intrinsic columns followed by fill use exactly three gaps")
	func threeIntrinsicThenFill() {
		let spec = specification(
			widths: [.intrinsic(), .intrinsic(), .intrinsic(), .fill()],
			cells: [TestCell(60), TestCell(70), TestCell(80), TestCell(500)]
		)

		let layout = spec.calculateLayout(spec.prepare(), for: CGSize(width: 400, height: .unbounded))

		#expect(layout.columnWidths == [60, 70, 80, 130])
		#expect(layout.columnOffsets == [0, 80, 170, 270])
		#expect(layout.size.width == 400)
		#expect(layout.columnOffsets[3] - (layout.columnOffsets[2] + layout.columnWidths[2]) == 20)
	}

	@Test("Zero intrinsic columns do not create hidden gaps")
	func zeroIntrinsicColumnsDoNotCreateGaps() {
		let spec = specification(
			widths: [.intrinsic(), .intrinsic(), .intrinsic(), .fill()],
			cells: [TestCell(50), TestCell(0), TestCell(0), TestCell(500)]
		)

		let layout = spec.calculateLayout(spec.prepare(), for: CGSize(width: 200, height: .unbounded))

		#expect(layout.columnWidths == [50, 0, 0, 130])
		#expect(layout.columnOffsets == [0, 0, 0, 70])
		#expect(layout.size.width == 200)
	}

	@Test("Prepared columns and fill columns are measured in separate passes")
	func preparedAndFillMeasurementStaySeparate() {
		let intrinsic = TestCell(80)
		let fill = TestCell(500)
		let spec = specification(
			widths: [.intrinsic(), .fill()],
			cells: [intrinsic, fill]
		)

		let prepared = spec.prepare()

		#expect(intrinsic.measuredBounds.count == 1)
		#expect(fill.measuredBounds.isEmpty)
		#expect(prepared.columnWidths == [80, 0])

		let layout = spec.calculateLayout(prepared, for: CGSize(width: 300, height: .unbounded))

		#expect(intrinsic.measuredBounds.count == 1)
		#expect(fill.measuredBounds.count == 1)
		#expect(fill.measuredBounds[0].width == 200)
		#expect(layout.columnWidths == [80, 200])
	}

	@Test("Cell rendering uses offsets returned by dimension application")
	func drawUsesAppliedOffsets() {
		var rendered: [JCSGrid.CellRender] = []
		let render = JCSGrid.Render(cell: { rendered.append($0) })
		let spec = specification(
			widths: [.intrinsic(), .fill()],
			cells: [TestCell(80), TestCell(500)],
			render: render
		)
		let layout = spec.calculateLayout(spec.prepare(), for: CGSize(width: 300, height: .unbounded))

		spec.draw(layout, CGRect(x: 10, y: 15, width: 300, height: layout.size.height))

		#expect(rendered.count == 2)
		#expect(rendered[0].rect.minX == 10)
		#expect(rendered[0].rect.width == 80)
		#expect(rendered[1].rect.minX == 110)
		#expect(rendered[1].rect.width == 200)
		#expect(rendered[1].rect.maxX == 310)
	}

	@Test("Rows use the same gap and offset semantics as columns")
	func rowOffsets() {
		let spec = specification(
			widths: [.fixed(100)],
			columnGap: 0,
			rowHeight: .intrinsic(),
			rowGap: 12,
			cells: [TestCell(100, 20), TestCell(100, 30), TestCell(100, 40)]
		)

		let layout = spec.calculateLayout(spec.prepare(), for: CGSize(width: 100, height: .unbounded))

		#expect(layout.rowHeights == [20, 30, 40])
		#expect(layout.rowOffsets == [0, 32, 74])
		#expect(layout.size.height == 114)
	}

	@Test("Fill rows use remaining height after intrinsic rows and gaps")
	func intrinsicAndFillRows() {
		let cells = [TestCell(100, 30), TestCell(100, 500)]
		let spec = JCSGrid.Specification(
			cols: [.init(.fixed(100), gap: 0)],
			rows: .init(def: { index in
				.init(index == 0 ? .intrinsic() : .fill(), gap: 10)
			}),
			cells: cells,
			render: .init()
		)

		let layout = spec.calculateLayout(spec.prepare(), for: CGSize(width: 100, height: 200))

		#expect(layout.rowHeights == [30, 160])
		#expect(layout.rowOffsets == [0, 40])
		#expect(layout.size.height == 200)
	}
}
