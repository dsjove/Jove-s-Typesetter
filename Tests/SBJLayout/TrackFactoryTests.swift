import CoreGraphics
import Testing
@testable import SBJLayout

@Suite("TrackFactory")
struct TrackFactoryTests {
	private func fixedValue(_ size: TrackSize) -> CGFloat? {
		guard case .fixed(let value) = size else { return nil }
		return value
	}

	@Test("Length initializer creates tracks with the supplied properties")
	func lengthInitializer() {
		let factory = TrackFactory(
			.fixed(12),
			align: .rightBottom,
			gap: 7,
			min: 2,
			max: 4
		)
		let track = factory.def(0)

		#expect(factory.min == 2)
		#expect(factory.max == 4)
		#expect(fixedValue(track.length) == 12)
		#expect(track.align == .rightBottom)
		#expect(track.gap == 7)
	}

	@Test("Column initializer produces exactly one track")
	func columnInitializer() {
		let track = Track(.fixed(15), align: .center, gap: 3)
		let factory = TrackFactory(col: track)

		#expect(factory.min == 1)
		#expect(factory.max == 1)
		#expect(fixedValue(factory.def(0).length) == 15)
		#expect(factory.def(0).align == .center)
		#expect(factory.def(0).gap == 3)
	}

	@Test("Row initializer preserves its range")
	func rowInitializer() {
		let track = Track(.fixed(9), align: .bottom, gap: 4)
		let factory = TrackFactory(row: track, min: 2, max: 5)

		#expect(factory.min == 2)
		#expect(factory.max == 5)
		#expect(fixedValue(factory.def(3).length) == 9)
		#expect(factory.def(3).align == .bottom)
		#expect(factory.def(3).gap == 4)
	}

	@Test("Array initializer returns tracks in array order by default")
	func arrayInitializer() {
		let factory = TrackFactory([
			Track(.fixed(10)),
			Track(.fixed(20)),
			Track(.fixed(30)),
		])

		#expect(factory.min == 1)
		#expect(factory.max == 3)
		#expect((0..<3).map { fixedValue(factory.def($0).length) } == [10, 20, 30])
	}

	@Test("Array mapping transforms each requested index")
	func mappedArrayInitializer() {
		let tracks = [
			Track(.fixed(10)),
			Track(.fixed(20)),
			Track(.fixed(30)),
		]
		var requestedIndices: [Int] = []
		let factory = TrackFactory(tracks) { index in
			requestedIndices.append(index)
			return [2, 0, 1][index]
		}

		let lengths = (0..<3).map { fixedValue(factory.def($0).length) }

		#expect(requestedIndices == [0, 1, 2])
		#expect(lengths == [30, 10, 20])
	}

	@Test("Definition initializer receives the requested index")
	func definitionInitializer() {
		var requestedIndices: [Int] = []
		let factory = TrackFactory(min: 1, max: 3) { index in
			requestedIndices.append(index)
			return Track(.fixed(CGFloat(index + 1)))
		}

		let lengths = (0..<3).map { fixedValue(factory.def($0).length) }

		#expect(requestedIndices == [0, 1, 2])
		#expect(lengths == [1, 2, 3])
	}
}
