import CoreGraphics

public struct Track {
	public let length: TrackSize
	public let align: Alignment
	public let gap: CGFloat
	public let aggregate: (CGFloat, CGFloat) -> CGFloat

	public init(
		_ length: TrackSize = .intrinsic(),
		align: Alignment = .left, //Column centric
		gap: CGFloat = 4.0,
		aggregate: @escaping (CGFloat, CGFloat) -> CGFloat = Swift.max
	) {
		self.length = length
		self.align = align
		self.gap = gap
		self.aggregate = aggregate
	}
}
