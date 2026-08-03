import CoreGraphics

public class TrackLayout {
// Init
	public let factory: ((Int)->Track)?
	public let count: Int
	public var isEmpty: Bool { count == 0 }
	public let layout: TrackArrangement
// Prepared
	public private(set) var elements: [Track]
	public private(set) var uniformCount: Int
	public var hasUniform: Bool { uniformCount > 0 }
	public private(set) var fillCount: Int
	public var hasFill: Bool { fillCount > 0 }
	public private(set) var baseLine: [CGFloat]
	public private(set) var baseLineSize: CGFloat
// Can change with hasFill
	private var lastBounds: CGFloat?
	public private(set) var lengths: [CGFloat]
	public private(set) var offsets: [CGFloat]
	public private(set) var size: CGFloat

	public init(
		factory: ((Int)->Track)? = nil,
		elements: [Track] = [],
		count :Int? = nil,
		layout: TrackArrangement
	) {
		self.factory = factory
		self.elements = elements
		self.count = count ?? elements.count
		self.layout = layout
		self.uniformCount = 0
		self.fillCount = 0
		self.baseLine = []
		self.lengths = []
		self.offsets = []
		self.size = 0
		self.baseLineSize = 0
	}

	public func apply(
		available: CGFloat = .unbounded,
		intrinsic: (
			_ index: Int,
			_ element: Track,
			_ bound: CGFloat
		) -> CGFloat
	) {
		if let factory, elements.isEmpty {
			elements = (0..<count).map(factory)
		}
		guard elements.isEmpty == false else { return }
		prepare(intrinsic)
		calculateFills(available)
	}

	private func prepare(
		_ intrinsic: (
			_ index: Int,
			_ element: Track,
			_ bound: CGFloat
		) -> CGFloat
	) {
		guard baseLine.isEmpty else { return }
		self.baseLine = Array(repeating: 0, count: elements.count)
		for (index, element) in elements.enumerated() {
			switch element.length {
			case .fixed(let length):
				self.baseLine[index] = length
			case .intrinsic(bound: let bound, min: let minimum):
				var length = intrinsic(index, element, bound)
				if let minimum { length = max(length, minimum) }
				self.baseLine[index] = length
			case .uniform(_):
				uniformCount += 1
				let length = intrinsic(index, element, .unbounded)
				self.baseLine[index] = length
			case .fill(let fraction, let mininum, let maximum):
				let lockedAtZero = maximum <= 0 || fraction.map {$0 <= 0} ?? false
				if !lockedAtZero { fillCount += 1 }
				let length = lockedAtZero ? 0 : max(0, mininum)
				self.baseLine[index] = length
			}
		}
		if hasUniform && elements.count > 1 {
			let snapshot = baseLine.dropFirst()
			let first = baseLine.first!
			for (index, element) in elements.enumerated() {
				switch element.length {
				case .uniform(let reduce):
// TODO: create identifiable reducers for optimization
					let length = snapshot.reduce(first) { accume, next in
						next > 0.0 ? reduce(accume, next) : accume
					}
					self.baseLine[index] = length
				default:
					break
				}
			}
		}
		self.lengths = baseLine
		self.baseLineSize = calculateSize()
		self.size = baseLineSize
	}

	private func calculateSize() -> CGFloat {
		offsets = Array(repeating: 0, count: elements.count)

		if layout == .stack {
			return lengths.reduce(0, max)
		}

		var size: CGFloat = 0
		var previousVisibleIndex: Int?

		for (index, length) in lengths.enumerated() {
			if length > 0, layout == .gaps, let previousVisibleIndex {
				size += elements[previousVisibleIndex].gap
			}

			offsets[index] = size

			if length > 0 {
				size += length
				previousVisibleIndex = index
			}
		}

		return size
	}

	private func calculateFills(_ available: CGFloat) {
		guard hasFill else { return }
		guard lastBounds != available else { return }
		lastBounds = available
		lengths = baseLine
		size = calculateSize()
		guard available != .unbounded else { return }

		let fillFraction = 1.0 / CGFloat(fillCount)
		if layout == .stack {
			for (index, element) in elements.enumerated() {
				switch element.length {
				case .fill(let fraction, let minimum, let maximum):
					let lockedAtZero = maximum <= 0 || fraction.map {$0 <= 0} ?? false
					if !lockedAtZero {
						let fraction = fraction.map { $0 >= 0.0 ? $0 : 0.0} ?? fillFraction
						let length = max(minimum, min(maximum, fraction * available))
						self.lengths[index] = length
					}
				default:
					break
				}
			}
		} else {
			var availableGrowth = max(0, available - baseLineSize)
			allocateFills(
				availableGrowth: availableGrowth,
				fillFraction: fillFraction
			)

			var calculatedSize = calculateSize()
			if calculatedSize > available {
				let overflow = calculatedSize - available
				availableGrowth = max(0, availableGrowth - overflow)
				lengths = baseLine
				allocateFills(
					availableGrowth: availableGrowth,
					fillFraction: fillFraction
				)
				calculatedSize = calculateSize()
			}
			self.size = calculatedSize
			return
		}
		self.size = calculateSize()
	}

	private func allocateFills(
		availableGrowth: CGFloat,
		fillFraction: CGFloat
	) {
		guard availableGrowth > 0 else { return }
		var remainingGrowth = availableGrowth

		for (index, element) in elements.enumerated() {
			guard remainingGrowth > 0 else { break }
			guard case .fill(let fraction, _, let maximum) = element.length else {
				continue
			}

			let lockedAtZero = maximum <= 0 || fraction.map { $0 <= 0 } ?? false
			guard !lockedAtZero else { continue }

			let capacity = max(0, maximum - baseLine[index])
			let requestedGrowth = (fraction ?? fillFraction) * availableGrowth
			let growth = min(requestedGrowth, capacity, remainingGrowth)

			lengths[index] = baseLine[index] + growth
			remainingGrowth -= growth
		}
	}
}
