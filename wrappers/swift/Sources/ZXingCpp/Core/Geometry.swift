// Copyright 2026 Axel Waggershauser
// SPDX-License-Identifier: Apache-2.0

import Foundation
import ZXingCBridge

public struct Point: Hashable, Sendable, CustomStringConvertible {
	public var x: Int
	public var y: Int

	public var description: String { "\(x)x\(y)" }

	public init(x: Int, y: Int) {
		self.x = x
		self.y = y
	}

	init(_ p: ZXing_PointI) {
		x = Int(p.x)
		y = Int(p.y)
	}
}

public struct Position: Hashable, Sendable, CustomStringConvertible {
	public var topLeft: Point
	public var topRight: Point
	public var bottomRight: Point
	public var bottomLeft: Point

	public var description: String {
		"topLeft=\(topLeft), topRight=\(topRight), bottomRight=\(bottomRight), bottomLeft=\(bottomLeft)"
	}

	init(_ p: ZXing_Position) {
		topLeft = Point(p.topLeft)
		topRight = Point(p.topRight)
		bottomRight = Point(p.bottomRight)
		bottomLeft = Point(p.bottomLeft)
	}
}
