import CoreGraphics

public struct Track {
	public typealias Aggregate = ([CGFloat]) -> CGFloat?

	public let length: TrackSize
	public let align: Alignment
	public let gap: CGFloat
	public let aggregate: Aggregate

	public init(
		_ length: TrackSize = .intrinsic(),
		align: Alignment = .left, //Column centric
		gap: CGFloat = 3.0,
		aggregate: @escaping Aggregate = { $0.max() }
	) {
		self.length = length
		self.align = align
		self.gap = gap
		self.aggregate = aggregate
	}

	public init(
		_ track: Track,
		aggregate: @escaping Aggregate
	) {
		self.init(
			track.length,
			align: track.align,
			gap: track.gap,
			aggregate: aggregate
		)
	}
}
