import CoreGraphics
import Testing
@testable import Jove_s_Typesetter

@Suite("JCSDimension.apply")
struct JCSDimensionApplyTests {
	private struct Item {
		let dimension: JCSDimension
		let gap: CGFloat
		let intrinsic: CGFloat

		init(
			_ dimension: JCSDimension,
			gap: CGFloat = 0,
			intrinsic: CGFloat = 0
		) {
			self.dimension = dimension
			self.gap = gap
			self.intrinsic = intrinsic
		}
	}

	private struct Resolution: Equatable {
		let index: Int
		let value: CGFloat
	}

	private func apply(
		_ items: [Item],
		available: CGFloat = .unbounded,
		fillConsumesSpace: Bool = true,
		didResolve: (
			_ index: Int,
			_ item: Item,
			_ value: CGFloat
		) -> Void = { _, _, _ in }
	) -> JCSDimension.Applied {
		JCSDimension.apply(
			to: items,
			dimension: \.dimension,
			gap: \.gap,
			available: available,
			fillConsumesSpace: fillConsumesSpace,
			intrinsic: { _, item, _ in item.intrinsic },
			didResolve: didResolve
		)
	}

	@Test("Empty input")
	func emptyInput() {
		let result = apply([])
		#expect(result.values.isEmpty)
		#expect(result.size == 0)
		#expect(result.hasFill == false)
	}

	@Test("Fixed dimensions")
	func fixedDimensions() {
		let result = apply([
			Item(.fixed(10)),
			Item(.fixed(20)),
			Item(.fixed(30))
		])

		#expect(result.values == [10, 20, 30])
		#expect(result.size == 60)
		#expect(result.hasFill == false)
	}

	@Test("Negative fixed dimensions clamp to zero")
	func negativeFixedDimensions() {
		let result = apply([
			Item(.fixed(-10)),
			Item(.fixed(20))
		])

		#expect(result.values == [0, 20])
		#expect(result.size == 20)
	}

	@Test("Fixed dimensions are not intrinsically measured")
	func fixedDoesNotMeasure() {
		let items = [Item(.fixed(10), intrinsic: 999)]
		var measurementCount = 0

		let result = JCSDimension.apply(
			to: items,
			dimension: \.dimension,
			gap: \.gap,
			available: 100,
			intrinsic: { _, item, _ in
				measurementCount += 1
				return item.intrinsic
			}
		)

		#expect(result.values == [10])
		#expect(measurementCount == 0)
	}

	@Test("Intrinsic value")
	func intrinsicValue() {
		let result = apply([
			Item(.intrinsic(), intrinsic: 42)
		])

		#expect(result.values == [42])
		#expect(result.size == 42)
	}

	@Test("Intrinsic minimum")
	func intrinsicMinimum() {
		let result = apply([
			Item(.intrinsic(min: 25), intrinsic: 10)
		])

		#expect(result.values == [25])
	}

	@Test("Intrinsic bound")
	func intrinsicBound() {
		let result = apply([
			Item(.intrinsic(bound: 30), intrinsic: 50)
		])

		#expect(result.values == [30])
	}

	@Test("Intrinsic minimum and bound")
	func intrinsicMinimumAndBound() {
		#expect(apply([
			Item(.intrinsic(bound: 50, min: 20), intrinsic: 10)
		]).values == [20])

		#expect(apply([
			Item(.intrinsic(bound: 50, min: 20), intrinsic: 30)
		]).values == [30])

		#expect(apply([
			Item(.intrinsic(bound: 50, min: 20), intrinsic: 80)
		]).values == [50])
	}

	@Test("Intrinsic receives its bound")
	func intrinsicReceivesBound() {
		let items = [Item(.intrinsic(bound: 75), intrinsic: 40)]
		var receivedBound: CGFloat?

		_ = JCSDimension.apply(
			to: items,
			dimension: \.dimension,
			gap: \.gap,
			available: 100,
			intrinsic: { _, item, bound in
				receivedBound = bound
				return item.intrinsic
			}
		)

		#expect(receivedBound == 75)
	}

	@Test("Uniform uses maximum by default")
	func uniformMaximum() {
		let result = apply([
			Item(.uniform(), intrinsic: 10),
			Item(.uniform(), intrinsic: 35),
			Item(.uniform(), intrinsic: 20)
		])

		#expect(result.values == [35, 35, 35])
		#expect(result.size == 105)
	}

	@Test("Uniform supports a custom reducer")
	func uniformCustomReducer() {
		let result = apply([
			Item(.uniform(min), intrinsic: 30),
			Item(.uniform(min), intrinsic: 10),
			Item(.uniform(min), intrinsic: 20)
		])

		#expect(result.values == [10, 10, 10])
	}

	@Test("First uniform reducer governs the group")
	func firstUniformReducerGovernsGroup() {
		let result = apply([
			Item(.uniform(max), intrinsic: 30),
			Item(.uniform(min), intrinsic: 10),
			Item(.uniform(min), intrinsic: 20)
		])

		#expect(result.values == [30, 30, 30])
	}

	@Test("Uniform receives an unbounded constraint")
	func uniformReceivesUnboundedConstraint() {
		let items = [
			Item(.uniform(), intrinsic: 10),
			Item(.uniform(), intrinsic: 20)
		]
		var bounds: [CGFloat] = []

		_ = JCSDimension.apply(
			to: items,
			dimension: \.dimension,
			gap: \.gap,
			available: 100,
			intrinsic: { _, item, bound in
				bounds.append(bound)
				return item.intrinsic
			}
		)

		#expect(bounds.count == 2)
		let r = bounds.allSatisfy(\.isUnbounded)
		#expect(r)
	}

	@Test("One consuming fill uses all available space")
	func oneConsumingFill() {
		let result = apply([Item(.fill())], available: 100)
		#expect(result.values == [100])
		#expect(result.size == 100)
		#expect(result.hasFill)
	}

	@Test("Consuming automatic fills divide available space")
	func consumingAutomaticFills() {
		let result = apply([
			Item(.fill()),
			Item(.fill()),
			Item(.fill()),
			Item(.fill())
		], available: 100)

		#expect(result.values == [25, 25, 25, 25])
		#expect(result.size == 100)
	}

	@Test("Consuming fill uses remaining space")
	func consumingFillUsesRemainingSpace() {
		let result = apply([
			Item(.fixed(30)),
			Item(.fill())
		], available: 100)

		#expect(result.values == [30, 70])
		#expect(result.size == 100)
	}

	@Test("Consuming explicit fractions")
	func consumingExplicitFractions() {
		let result = apply([
			Item(.fill(0.25)),
			Item(.fill(0.75))
		], available: 200)

		#expect(result.values == [50, 150])
		#expect(result.size == 200)
	}

	@Test("Consuming automatic fills divide unclaimed fraction")
	func consumingAutomaticFillsDivideUnclaimedFraction() {
		let result = apply([
			Item(.fill(0.25)),
			Item(.fill()),
			Item(.fill())
		], available: 200)

		#expect(result.values == [50, 75, 75])
		#expect(result.size == 200)
	}

	@Test("Consuming fills clamp to remaining space")
	func consumingFillClampsToRemaining() {
		let result = apply([
			Item(.fill(0.75)),
			Item(.fill(0.75))
		], available: 100)

		#expect(result.values == [75, 25])
		#expect(result.size == 100)
	}

	@Test("One non-consuming fill uses full available extent")
	func oneNonConsumingFill() {
		let result = apply(
			[Item(.fill())],
			available: 100,
			fillConsumesSpace: false
		)

		#expect(result.values == [100])
		#expect(result.size == 100)
	}

	@Test("All non-consuming automatic fills use full available extent")
	func nonConsumingAutomaticFills() {
		let result = apply(
			[
				Item(.fill()),
				Item(.fill()),
				Item(.fill())
			],
			available: 100,
			fillConsumesSpace: false
		)

		#expect(result.values == [100, 100, 100])
		#expect(result.size == 100)
	}

	@Test("Non-consuming explicit fills do not reduce one another")
	func nonConsumingExplicitFills() {
		let result = apply(
			[
				Item(.fill(0.75)),
				Item(.fill(0.75))
			],
			available: 100,
			fillConsumesSpace: false
		)

		#expect(result.values == [75, 75])
		#expect(result.size == 75)
	}

	@Test("Non-consuming automatic fill ignores explicit fraction total")
	func nonConsumingAutomaticFillIgnoresExplicitTotal() {
		let result = apply(
			[
				Item(.fill(0.25)),
				Item(.fill()),
				Item(.fill())
			],
			available: 200,
			fillConsumesSpace: false
		)

		#expect(result.values == [50, 200, 200])
		#expect(result.size == 200)
	}

	@Test("Non-consuming size is maximum resolved extent")
	func nonConsumingSizeIsMaximum() {
		let result = apply(
			[
				Item(.fixed(30)),
				Item(.intrinsic(), intrinsic: 50),
				Item(.fill(0.75))
			],
			available: 100,
			fillConsumesSpace: false
		)

		// Existing non-fill content occupies 50 points, leaving 50 points for
		// fill. The fill resolves to 37.5, and the overlay extent stays 50.
		#expect(result.values == [30, 50, 37.5])
		#expect(result.size == 50)
	}

	@Test("Non-consuming layouts ignore gaps")
	func nonConsumingIgnoresGaps() {
		let result = apply(
			[
				Item(.fixed(20), gap: 100),
				Item(.fill(), gap: 100),
				Item(.fill(), gap: 100)
			],
			available: 100,
			fillConsumesSpace: false
		)

		#expect(result.values == [20, 80, 80])
		#expect(result.size == 80)
	}

	@Test("Zero and negative fill fractions resolve to zero")
	func nonPositiveFillFractions() {
		for consumes in [true, false] {
			let result = apply(
				[
					Item(.fill(0)),
					Item(.fill(-0.5))
				],
				available: 100,
				fillConsumesSpace: consumes
			)

			#expect(result.values == [0, 0])
			#expect(result.size == 0)
			#expect(result.hasFill)
		}
	}

	@Test("Unbounded available space gives fill zero")
	func unboundedAvailableSpace() {
		for consumes in [true, false] {
			let result = apply(
				[
					Item(.fixed(20)),
					Item(.fill())
				],
				available: .unbounded,
				fillConsumesSpace: consumes
			)

			#expect(result.values == [20, 0])
			#expect(result.size == 20)
		}
	}

	@Test("Sequential gaps are included only between resolved values")
	func sequentialGaps() {
		let result = apply([
			Item(.fixed(10), gap: 3),
			Item(.fixed(20), gap: 5),
			Item(.fixed(30), gap: 100)
		])

		#expect(result.values == [10, 20, 30])
		#expect(result.size == 68)
	}

	@Test("Zero-sized sequential values do not create gaps")
	func zeroSizedValuesDoNotCreateGaps() {
		let result = apply([
			Item(.fixed(10), gap: 4),
			Item(.fixed(0), gap: 50),
			Item(.fixed(20), gap: 100)
		])

		#expect(result.values == [10, 0, 20])
		#expect(result.size == 34)
	}

	@Test("Negative gaps clamp to zero")
	func negativeGaps() {
		let result = apply([
			Item(.fixed(10), gap: -5),
			Item(.fixed(20))
		])

		#expect(result.size == 30)
	}

	@Test("All dimension types work together")
	func mixedDimensions() {
		let result = apply([
			Item(.fixed(10), gap: 2),
			Item(.intrinsic(), gap: 3, intrinsic: 20),
			Item(.uniform(), gap: 4, intrinsic: 15),
			Item(.uniform(), gap: 5, intrinsic: 25),
			Item(.fill())
		], available: 150)

		#expect(result.values == [10, 20, 25, 25, 56])
		#expect(result.size == 150)
		#expect(result.hasFill)
	}

	@Test("didResolve is called once per element")
	func didResolveCalledOncePerElement() {
		let items = [
			Item(.fixed(10)),
			Item(.intrinsic(), intrinsic: 20),
			Item(.uniform(), intrinsic: 30),
			Item(.fill())
		]
		var resolutions: [Resolution] = []

		let result = apply(items, available: 100) { index, _, value in
			resolutions.append(.init(index: index, value: value))
		}

		#expect(resolutions.count == items.count)
		#expect(Set(resolutions.map(\.index)) == Set(items.indices))

		for index in result.values.indices {
			#expect(
				resolutions.first { $0.index == index }?.value
					== result.values[index]
			)
		}
	}

	@Test("Non-fill callbacks occur before fill callbacks")
	func callbackOrder() {
		let items = [
			Item(.fill()),
			Item(.fixed(10)),
			Item(.fill()),
			Item(.intrinsic(), intrinsic: 20)
		]
		var indices: [Int] = []

		_ = apply(items, available: 100) { index, _, _ in
			indices.append(index)
		}

		#expect(indices == [1, 3, 0, 2])
	}

	@Test("Result contains one value per input")
	func resultCount() {
		let items = [
			Item(.fixed(10)),
			Item(.intrinsic(), intrinsic: 20),
			Item(.uniform(), intrinsic: 30),
			Item(.fill())
		]

		#expect(apply(items, available: 100).values.count == items.count)
	}

	@Test("Prepared values resolve only fill dimensions")
	func preparedValuesResolveOnlyFillDimensions() {
		let items = [
			Item(.fixed(20), gap: 5),
			Item(.intrinsic(), gap: 5, intrinsic: 999),
			Item(.fill())
		]
		let prepared = JCSDimension.Applied(
			values: [20, 30, 0],
			size: 55,
			hasFill: true
		)
		var intrinsicCount = 0
		var resolutions: [Resolution] = []

		let result = JCSDimension.apply(
			to: items,
			dimension: \.dimension,
			gap: \.gap,
			available: 100,
			prepared: prepared,
			intrinsic: { _, _, _ in
				intrinsicCount += 1
				return 999
			},
			didResolve: { index, _, value in
				resolutions.append(.init(index: index, value: value))
			}
		)

		#expect(result.values == [20, 30, 40])
		#expect(result.size == 100)
		#expect(intrinsicCount == 0)
		#expect(resolutions == [.init(index: 2, value: 40)])
	}

	@Test("Prepared fill values are discarded before redistribution")
	func preparedFillValuesAreDiscarded() {
		let items = [Item(.fixed(20)), Item(.fill())]
		let prepared = JCSDimension.Applied(
			values: [20, 500],
			hasFill: true
		)

		let result = JCSDimension.apply(
			to: items,
			dimension: \.dimension,
			gap: \.gap,
			available: 100,
			prepared: prepared,
			intrinsic: { _, _, _ in 0 }
		)

		#expect(result.values == [20, 80])
		#expect(result.size == 100)
	}

	@Test("Automatic fills receive no fraction after explicit fills claim all space")
	func automaticFillAfterFullyClaimedFraction() {
		let result = apply([
			Item(.fill(1)),
			Item(.fill())
		], available: 100)

		#expect(result.values == [100, 0])
		#expect(result.size == 100)
	}


	@Test("Trailing zero-sized values do not leave a gap")
	func trailingZeroSizedValuesDoNotLeaveGap() {
		let result = apply([
			Item(.fixed(10), gap: 4),
			Item(.fixed(20), gap: 50),
			Item(.fixed(0), gap: 100)
		])

		#expect(result.values == [10, 20, 0])
		#expect(result.size == 34)
	}

	@Test("Intrinsic minimum above bound resolves to bound")
	func intrinsicMinimumAboveBound() {
		let result = apply([
			Item(.intrinsic(bound: 20, min: 30), intrinsic: 10)
		])

		#expect(result.values == [20])
	}

}
