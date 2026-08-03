import CoreGraphics

public struct TrackFactory {
	let min: Int
	let max: Int
	let def: (Int)->Track

	public init(
		_ length: TrackSize = .intrinsic(),
		align: Alignment = .top,
		gap: CGFloat = 2.0,
		min: Int = 0,
		max: Int = Int.max
	) {
		self.init(min: min, max: max) { _ in .init(length, align: align, gap: gap) }
	}

	public init(x
		min: Int = 0,
		max: Int = Int.max,
		_ def: Track
	) {
		self.init(min: min, max: max) { _ in def }
	}

	public init(
		min: Int = 0,
		max: Int = Int.max,
		def: @escaping (Int) -> Track
	) {
		self.min = min
		self.max = max
		self.def = def
	}
}
