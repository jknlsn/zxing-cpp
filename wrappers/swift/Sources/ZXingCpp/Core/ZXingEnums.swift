// Copyright 2026 Axel Waggershauser
// SPDX-License-Identifier: Apache-2.0

import Foundation
import ZXingCBridge

public enum ImageFormat: Int32, Sendable {
	case none = 0
	case lum  = 0x01000000
	case lumA = 0x02000000
	case rgb  = 0x03000102
	case bgr  = 0x03020100
	case rgba = 0x04000102
	case argb = 0x04010203
	case bgra = 0x04020100
	case abgr = 0x04030201

	/// The number of bytes per pixel for this format.
	///
	/// Derived from the high byte of the raw value, matching the C++ `PixStride()` function.
	public var bytesPerPixel: Int { Int(rawValue >> 24) & 0xFF }
}

public enum ContentType: Int32, Sendable, CustomStringConvertible {
	case text       = 0
	case binary     = 1
	case mixed      = 2
	case gs1        = 3
	case iso15434   = 4
	case unknownECI = 5

	public var description: String {
		guard let contentType: ZXing_ContentType = cEnum(rawValue) else {
			return "Unknown ContentType(\(rawValue))"
		}
		return c2s(ZXing_ContentTypeToString(contentType))
	}
}

public enum ErrorType: Int32, Sendable {
	case none        = 0
	case format      = 1
	case checksum    = 2
	case unsupported = 3
}

public enum Binarizer: Int32, Sendable {
	case localAverage    = 0
	case globalHistogram = 1
	case fixedThreshold  = 2
	case boolCast        = 3
}

public enum EanAddOnSymbol: Int32, Sendable {
	case ignore  = 0
	case read    = 1
	case require = 2
}

public enum TextMode: Int32, Sendable {
	case plain   = 0
	case eci     = 1
	case hri     = 2
	case escaped = 3
	case hex     = 4
	case hexECI  = 5
}

/// Fallback character set override used when a barcode does not provide reliable encoding metadata.
public enum CharacterSet: Int32, Sendable {
	case unknown = 0
	case ascii = 1
	case iso8859_1 = 2
	case iso8859_2 = 3
	case iso8859_3 = 4
	case iso8859_4 = 5
	case iso8859_5 = 6
	case iso8859_6 = 7
	case iso8859_7 = 8
	case iso8859_8 = 9
	case iso8859_9 = 10
	case iso8859_10 = 11
	case iso8859_11 = 12
	case iso8859_13 = 13
	case iso8859_14 = 14
	case iso8859_15 = 15
	case iso8859_16 = 16
	case cp437 = 17
	case cp1250 = 18
	case cp1251 = 19
	case cp1252 = 20
	case cp1256 = 21
	case shiftJIS = 22
	case big5 = 23
	case gb2312 = 24
	case gb18030 = 25
	case eucJP = 26
	case eucKR = 27
	case utf16BE = 28
	case utf8 = 29
	case utf16LE = 30
	case utf32BE = 31
	case utf32LE = 32
	case binary = 33
}
