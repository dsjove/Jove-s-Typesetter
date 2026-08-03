import Testing
import CoreGraphics
@testable import Jove_s_Typesetter

@Suite("TrackLayout")
struct TrackLayoutTests {
    private let accuracy: CGFloat = 0.0001

    private func apply(
        _ widths: TrackLayout,
        available: CGFloat = .unbounded,
        intrinsicValues: [CGFloat] = []
    ) {
        widths.apply(available: available) { index, _, _ in
            guard intrinsicValues.indices.contains(index) else { return 0 }
            return intrinsicValues[index]
        }
    }

    private func expectEqual(_ actual: CGFloat, _ expected: CGFloat) {
        #expect(abs(actual - expected) <= accuracy)
    }

    private func expectEqual(_ actual: [CGFloat], _ expected: [CGFloat]) {
        #expect(actual.count == expected.count)
        for (actualValue, expectedValue) in zip(actual, expected) {
            expectEqual(actualValue, expectedValue)
        }
    }

    // MARK: - Baseline sizing

    @Test
    func testFixedTightLayoutAddsLengths() {
        let widths = TrackLayout(
            elements: [
                Track(.fixed(20)),
                Track(.fixed(30)),
                Track(.fixed(40))
            ],
            layout: .tight
        )

        apply(widths)

        expectEqual(widths.lengths, [20, 30, 40])
        expectEqual(widths.offsets, [0, 20, 50])
        expectEqual(widths.baseLineSize, 90)
        expectEqual(widths.size, 90)
    }

    @Test
    func testGapLayoutOmitsTrailingGap() {
        let widths = TrackLayout(
            elements: [
                Track(.fixed(20), gap: 3),
                Track(.fixed(30), gap: 5),
                Track(.fixed(40), gap: 7)
            ],
            layout: .gaps
        )

        apply(widths)

        // 20 + 3 + 30 + 5 + 40; the last element's gap is omitted.
        expectEqual(widths.offsets, [0, 23, 58])
        expectEqual(widths.size, 98)
    }

    @Test
    func testGapLayoutSkipsZeroLengthElements() {
        let widths = TrackLayout(
            elements: [
                Track(.fixed(20), gap: 3),
                Track(.fixed(0), gap: 100),
                Track(.fixed(30), gap: 5)
            ],
            layout: .gaps
        )

        apply(widths)

        expectEqual(widths.offsets, [0, 20, 23])
        expectEqual(widths.size, 53)
    }

    @Test
    func testStackLayoutUsesLargestLength() {
        let widths = TrackLayout(
            elements: [
                Track(.fixed(20)),
                Track(.fixed(50)),
                Track(.fixed(30))
            ],
            layout: .stack
        )

        apply(widths)

        expectEqual(widths.offsets, [0, 0, 0])
        expectEqual(widths.size, 50)
    }

    // MARK: - Intrinsic and uniform

    @Test
    func testIntrinsicUsesProvidedBoundAndMinimum() {
        var receivedBounds: [CGFloat] = []
        let widths = TrackLayout(
            elements: [
                Track(.intrinsic(bound: 80, min: 25)),
                Track(.intrinsic(bound: 40, min: 25))
            ],
            layout: .tight
        )

        widths.apply { index, _, bound in
            receivedBounds.append(bound)
            return index == 0 ? 10 : 35
        }

        expectEqual(widths.lengths, [25, 35])
        expectEqual(widths.offsets, [0, 25])
        expectEqual(receivedBounds, [80, 40])
        expectEqual(widths.size, 60)
    }

    @Test
    func testUniformDefaultsToLargestPositiveBaselineLength() {
        let widths = TrackLayout(
            elements: [
                Track(.uniform()),
                Track(.intrinsic()),
                Track(.fixed(40))
            ],
            layout: .tight
        )

        apply(widths, intrinsicValues: [10, 25, 0])

        expectEqual(widths.lengths, [40, 25, 40])
        expectEqual(widths.offsets, [0, 40, 65])
        #expect(widths.uniformCount == 1)
        #expect(widths.hasUniform)
    }

    @Test
    func testUniformSupportsCustomReducer() {
        let widths = TrackLayout(
            elements: [
                Track(.uniform(+)),
                Track(.fixed(20)),
                Track(.fixed(30))
            ],
            layout: .tight
        )

        apply(widths, intrinsicValues: [10, 0, 0])

        expectEqual(widths.lengths, [60, 20, 30])
        expectEqual(widths.offsets, [0, 60, 80])
    }

    // MARK: - Linear fill

    @Test
    func testSingleFillConsumesAvailableGrowth() {
        let widths = TrackLayout(
            elements: [
                Track(.fixed(100)),
                Track(.fill())
            ],
            layout: .tight
        )

        apply(widths, available: 300)

        expectEqual(widths.lengths, [100, 200])
        expectEqual(widths.offsets, [0, 100])
        expectEqual(widths.size, 300)
    }

    @Test
    func testEqualFillsSplitAvailableGrowth() {
        let widths = TrackLayout(
            elements: [
                Track(.fixed(100)),
                Track(.fill()),
                Track(.fill())
            ],
            layout: .tight
        )

        apply(widths, available: 300)

        expectEqual(widths.lengths, [100, 100, 100])
        expectEqual(widths.offsets, [0, 100, 200])
        expectEqual(widths.size, 300)
    }

    @Test
    func testFillMinimumIsIncludedInBaselineThenGrowthIsAdded() {
        let widths = TrackLayout(
            elements: [
                Track(.fixed(100)),
                Track(.fill(min: 50))
            ],
            layout: .tight
        )

        apply(widths, available: 300)

        expectEqual(widths.baseLine, [100, 50])
        expectEqual(widths.baseLineSize, 150)
        expectEqual(widths.lengths, [100, 200])
        expectEqual(widths.offsets, [0, 100])
        expectEqual(widths.size, 300)
    }

    @Test
    func testFillMaximumLimitsGrowth() {
        let widths = TrackLayout(
            elements: [
                Track(.fixed(100)),
                Track(.fill(max: 75))
            ],
            layout: .tight
        )

        apply(widths, available: 300)

        expectEqual(widths.lengths, [100, 75])
        expectEqual(widths.offsets, [0, 100])
        expectEqual(widths.size, 175)
    }

    @Test
    func testExplicitFractionsCannotExceedRemainingSpace() {
        let widths = TrackLayout(
            elements: [
                Track(.fill(0.75)),
                Track(.fill(0.75))
            ],
            layout: .tight
        )

        apply(widths, available: 200)

        expectEqual(widths.lengths, [150, 50])
        expectEqual(widths.offsets, [0, 150])
        expectEqual(widths.size, 200)
    }

    @Test
    func testZeroFractionFillIsLockedAtZero() {
        let widths = TrackLayout(
            elements: [
                Track(.fill(0, min: 20)),
                Track(.fill())
            ],
            layout: .tight
        )

        apply(widths, available: 100)

        expectEqual(widths.lengths, [0, 100])
        expectEqual(widths.offsets, [0, 0])
        #expect(widths.fillCount == 1)
    }

    // MARK: - Gap correction

    @Test
    func testNewlyVisibleFillGapIsDeductedFromGrowth() {
        let widths = TrackLayout(
            elements: [
                Track(.fixed(100), gap: 10),
                Track(.fill(), gap: 20)
            ],
            layout: .gaps
        )

        apply(widths, available: 300)

        // The first pass gives the fill 200, producing a total of 310.
        // The correction removes the 10-point overflow from fill growth.
        expectEqual(widths.lengths, [100, 190])
        expectEqual(widths.offsets, [0, 110])
        expectEqual(widths.size, 300)
    }

    @Test
    func testPositiveFillMinimumDoesNotAddAnotherGap() {
        let widths = TrackLayout(
            elements: [
                Track(.fixed(100), gap: 10),
                Track(.fill(min: 50), gap: 20)
            ],
            layout: .gaps
        )

        apply(widths, available: 300)

        // The gap already exists in the baseline because the fill minimum is positive.
        expectEqual(widths.baseLine, [100, 50])
        expectEqual(widths.baseLineSize, 160)
        expectEqual(widths.lengths, [100, 190])
        expectEqual(widths.offsets, [0, 110])
        expectEqual(widths.size, 300)
    }

    @Test
    func testZeroLengthElementBetweenVisibleElementsDoesNotAddGap() {
        let widths = TrackLayout(
            elements: [
                Track(.fixed(100), gap: 10),
                Track(.fill(0), gap: 100),
                Track(.fixed(50), gap: 20)
            ],
            layout: .gaps
        )

        apply(widths, available: 500)

        expectEqual(widths.lengths, [100, 0, 50])
        expectEqual(widths.offsets, [0, 100, 110])
        expectEqual(widths.size, 160)
    }

    // MARK: - Stack fill

    @Test
    func testStackFillUsesFractionOfEntireAvailableSize() {
        let widths = TrackLayout(
            elements: [
                Track(.fixed(80)),
                Track(.fill(0.5))
            ],
            layout: .stack
        )

        apply(widths, available: 300)

        expectEqual(widths.lengths, [80, 150])
        expectEqual(widths.offsets, [0, 0])
        expectEqual(widths.size, 150)
    }

    @Test
    func testStackFillHonorsMinimumAndMaximum() {
        let minimumWidths = TrackLayout(
            elements: [Track(.fill(0.1, min: 50, max: 200))],
            layout: .stack
        )
        apply(minimumWidths, available: 300)
        expectEqual(minimumWidths.lengths, [50])
        expectEqual(minimumWidths.offsets, [0])

        let maximumWidths = TrackLayout(
            elements: [Track(.fill(1, min: 0, max: 120))],
            layout: .stack
        )
        apply(maximumWidths, available: 300)
        expectEqual(maximumWidths.lengths, [120])
        expectEqual(maximumWidths.offsets, [0])
    }

    // MARK: - Cache behavior

    @Test
    func testRepeatedBoundUsesCachedFillResult() {
        let widths = TrackLayout(
            elements: [Track(.fill())],
            layout: .tight
        )
        var intrinsicCallCount = 0

        let intrinsic: (Int, Track, CGFloat) -> CGFloat = { _, _, _ in
            intrinsicCallCount += 1
            return 0
        }

        widths.apply(available: 200, intrinsic: intrinsic)
        let firstLengths = widths.lengths
        let firstOffsets = widths.offsets
        let firstSize = widths.size

        widths.apply(available: 200, intrinsic: intrinsic)

        expectEqual(widths.lengths, firstLengths)
        expectEqual(widths.offsets, firstOffsets)
        expectEqual(widths.size, firstSize)
        #expect(intrinsicCallCount == 0)
    }

    @Test
    func testChangedBoundRecalculatesFromBaseline() {
        let widths = TrackLayout(
            elements: [
                Track(.fixed(100)),
                Track(.fill())
            ],
            layout: .tight
        )

        apply(widths, available: 300)
        expectEqual(widths.lengths, [100, 200])

        apply(widths, available: 200)
        expectEqual(widths.lengths, [100, 100])
        expectEqual(widths.offsets, [0, 100])
        expectEqual(widths.size, 200)
    }

    @Test
    func testUnboundedAfterBoundedRestoresBaseline() {
        let widths = TrackLayout(
            elements: [
                Track(.fixed(100)),
                Track(.fill(min: 25))
            ],
            layout: .tight
        )

        apply(widths, available: 300)
        expectEqual(widths.lengths, [100, 200])

        apply(widths, available: .unbounded)

        expectEqual(widths.lengths, [100, 25])
        expectEqual(widths.offsets, [0, 100])
        expectEqual(widths.size, 125)
    }

    // MARK: - Empty input

    @Test
    func testEmptyElementsRemainEmpty() {
        let widths = TrackLayout(elements: [], layout: .tight)

        apply(widths, available: 100)

        #expect(widths.lengths.isEmpty)
        #expect(widths.offsets.isEmpty)
        expectEqual(widths.size, 0)
    }
}
