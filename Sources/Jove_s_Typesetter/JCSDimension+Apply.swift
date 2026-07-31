import CoreGraphics

extension JCSDimension {
	public struct Applied {
		public let values: [CGFloat]
		public let size: CGFloat
		public let hasFill: Bool

		public init(
			values: [CGFloat] = [],
			size: CGFloat = 0,
			hasFill: Bool = false
		) {
			self.values = values
			self.size = size
			self.hasFill = hasFill
		}
	}

	public static func apply<Element>(
		to elements: [Element],
		dimension: KeyPath<Element, JCSDimension>,
		gap: KeyPath<Element, CGFloat>,
		available: CGFloat,
		fillConsumesSpace: Bool = true,
		prepared: Applied? = nil,
		intrinsic: (
			_ index: Int,
			_ element: Element,
			_ bound: CGFloat
		) -> CGFloat,
		didResolve: (
			_ index: Int,
			_ element: Element,
			_ value: CGFloat
		) -> Void = { _, _, _ in }
	) -> Applied {
		guard !elements.isEmpty else { return .init() }

		var values: [CGFloat]
		var fillIndices: [Int] = []

		if let prepared {
			precondition(
				prepared.values.count == elements.count,
				"Prepared values must match the element count."
			)
			values = prepared.values

			for (index, element) in elements.enumerated() {
				if case .fill = element[keyPath: dimension] {
					values[index] = 0
					fillIndices.append(index)
				}
			}
		} else {
			values = Array(
				repeating: CGFloat.zero,
				count: elements.count
			)

			var uniformCandidates: [(index: Int, value: CGFloat)] = []
			var uniformReduce: ((CGFloat, CGFloat) -> CGFloat)?

			// Resolve fixed and intrinsic dimensions. Collect uniform and fill
			// dimensions for later passes.
			for (index, element) in elements.enumerated() {
				switch element[keyPath: dimension] {
				case .fixed(let value):
					values[index] = max(value, 0)

				case .intrinsic(let bound, let minimum):
					var value = intrinsic(index, element, bound)

					if let minimum {
						value = max(value, minimum)
					}

					if !bound.isUnbounded {
						value = min(value, bound)
					}

					values[index] = max(value, 0)

				case .uniform(let reduce):
					let value = intrinsic(index, element, .unbounded)
					uniformCandidates.append((index, max(value, 0)))

					if uniformReduce == nil {
						uniformReduce = reduce
					}

				case .fill:
					fillIndices.append(index)
				}
			}

			// The first uniform element defines the reduction operation for the group.
			if
				let first = uniformCandidates.first,
				let reduce = uniformReduce
			{
				let uniformValue = uniformCandidates
					.dropFirst()
					.reduce(first.value) {
						reduce($0, $1.value)
					}

				for candidate in uniformCandidates {
					values[candidate.index] = max(uniformValue, 0)
				}
			}

			// Non-fill values are known before available space is distributed.
			for (index, element) in elements.enumerated() {
				if case .fill = element[keyPath: dimension] {
					continue
				}

				didResolve(index, element, values[index])
			}
		}

		let activeIndices = elements.indices.filter { index in
			switch elements[index][keyPath: dimension] {
			case .fill(let fraction):
				return fraction == nil || fraction! > 0
			default:
				return values[index] > 0
			}
		}

		let consumedContent = fillConsumesSpace
			? values.reduce(0, +)
			: (values.max() ?? 0)

		let consumedGaps: CGFloat
		if fillConsumesSpace {
			consumedGaps = activeIndices
				.dropLast()
				.reduce(CGFloat.zero) { result, index in
					result + max(elements[index][keyPath: gap], 0)
				}
		} else {
			// Overlapping elements do not consume sequential gap space.
			consumedGaps = 0
		}

		let availableFill: CGFloat
		if available.isUnbounded {
			availableFill = 0
		} else {
			availableFill = max(
				available - consumedContent - consumedGaps,
				0
			)
		}

		let automaticFillCount = fillIndices.reduce(into: 0) { count, index in
			if case .fill(nil) = elements[index][keyPath: dimension] {
				count += 1
			}
		}

		let explicitFractionTotal = fillIndices.reduce(CGFloat.zero) { result, index in
			guard
				case .fill(let fraction?) = elements[index][keyPath: dimension],
				fraction > 0
			else {
				return result
			}

			return result + fraction
		}

		let automaticFraction: CGFloat
		if fillConsumesSpace {
			if automaticFillCount > 0 {
				automaticFraction =
					max(1 - explicitFractionTotal, 0)
					/ CGFloat(automaticFillCount)
			} else {
				automaticFraction = 0
			}
		} else {
			// Every unspecified fill in an overlapping layout fills the same
			// available extent.
			automaticFraction = 1
		}

		var remainingFill = availableFill

		for index in fillIndices {
			let element = elements[index]

			guard case .fill(let fraction) = element[keyPath: dimension] else {
				continue
			}

			let resolvedFraction = fraction ?? automaticFraction
			let requested = max(availableFill * resolvedFraction, 0)

			let resolved: CGFloat
			if fillConsumesSpace {
				resolved = min(requested, remainingFill)
				remainingFill -= resolved
			} else {
				resolved = requested
			}

			values[index] = resolved
			didResolve(index, element, resolved)
		}

		let size: CGFloat
		if fillConsumesSpace {
			let resolvedIndices = values.indices.filter { values[$0] > 0 }
			let resolvedGaps = resolvedIndices
				.dropLast()
				.reduce(CGFloat.zero) { result, index in
					result + max(elements[index][keyPath: gap], 0)
				}

			size = values.reduce(0, +) + resolvedGaps
		} else {
			// Overlapping values occupy the same axis, so the extent is the
			// largest resolved value rather than their sum.
			size = values.max() ?? 0
		}

		return .init(
			values: values,
			size: size,
			hasFill: !fillIndices.isEmpty
		)
	}
}
