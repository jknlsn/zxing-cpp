// Copyright 2026 Axel Waggershauser
// SPDX-License-Identifier: Apache-2.0

import Foundation

/// Extended Channel Interpretation configuration for barcode creation.
public enum ECI: Sendable, Hashable {
	case utf8
	case iso8859_1
	case ascii
	case shiftJIS
	case binary
	case name(String)
	case value(Int)

	internal func serializedValue() throws -> String {
		switch self {
		case .utf8:
			return "UTF-8"
		case .iso8859_1:
			return "ISO-8859-1"
		case .ascii:
			return "ASCII"
		case .shiftJIS:
			return "Shift_JIS"
		case .binary:
			return "Binary"
		case .name(let value):
			return value
		case .value(let value):
			guard value >= 0 else { throw ZXingError("ECI.value must be non-negative") }
			return String(value)
		}
	}
}
