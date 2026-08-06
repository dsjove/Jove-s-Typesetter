import CoreGraphics

public struct TrackFactory {
	let min: Int
	let max: Int
	let def: (Int)->Track

	public init(
		_ length: TrackSize = .intrinsic(),
		align: Alignment = .top,
		gap: CGFloat = 2.0,
		aggregate: @escaping (CGFloat, CGFloat) -> CGFloat = Swift.max,
		min: Int = 0,
		max: Int = Int.max
	) {
		self.init(min: min, max: max) { _ in .init(length, align: align, gap: gap, aggregate: aggregate) }
	}

	public init(
		col track: Track
	) {
		self.init(min: 1, max: 1) { _ in track }
	}

	public init(
		row track: Track,
		min: Int = 0,
		max: Int = Int.max
	) {
		self.init(min: min, max: max) { _ in track }
	}

	public init(
		_ tracks: [Track],
		map: ((Int)->Int)? = nil
	) {
		self.init(min: 1, max: tracks.count) { idx in tracks[map.map{$0(idx)} ?? idx] }
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
