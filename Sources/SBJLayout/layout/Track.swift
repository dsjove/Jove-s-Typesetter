import CoreGraphics

public struct Track {
	public let length: TrackSize
	public let align: Alignment
	public let gap: CGFloat

	public init(
		_ length: TrackSize = .intrinsic(),
		align: Alignment = .left, //Column centric
		gap: CGFloat = 2.0
	) {
		self.length = length
		self.align = align
		self.gap = gap
	}
}
