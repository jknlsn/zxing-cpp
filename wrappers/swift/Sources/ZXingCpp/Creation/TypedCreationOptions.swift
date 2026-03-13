// Copyright 2026 Axel Waggershauser
// SPDX-License-Identifier: Apache-2.0

import Foundation

/// QR-family error correction levels.
public enum QRCodeErrorCorrection: String, Sendable, Hashable {
	case low = "L"
	case medium = "M"
	case quartile = "Q"
	case high = "H"
}

/// QR-family data mask patterns.
public enum QRCodeDataMask: Int, Sendable, Hashable {
	case pattern0 = 0
	case pattern1 = 1
	case pattern2 = 2
	case pattern3 = 3
	case pattern4 = 4
	case pattern5 = 5
	case pattern6 = 6
	case pattern7 = 7
}

/// MaxiCode operating modes accepted by the current creator bridge.
public enum MaxiCodeMode: Int, Sendable, Hashable {
	case mode2 = 2
	case mode3 = 3
	case mode4 = 4
	case mode5 = 5
	case mode6 = 6
}

/// PDF417 error correction levels accepted by the current native creator bridge.
public enum PDF417ErrorCorrectionLevel: Int, Sendable, Hashable {
	case level0 = 0
	case level1 = 1
	case level2 = 2
	case level3 = 3
	case level4 = 4
	case level5 = 5
	case level6 = 6
	case level7 = 7
	case level8 = 8
}

/// Typed creation options for QR Code, QR Model 2, Micro QR, and rMQR.
public struct QRCodeOptions: Sendable, Hashable {
	/// Error correction level such as `.medium` or `.high`.
	public var errorCorrection: QRCodeErrorCorrection?
	/// Character encoding / ECI designator.
	public var eci: ECI?
	/// Whether the payload is GS1 data.
	/// Serialized only when `true`; `false` is omitted to match the native creator's presence-based semantics.
	public var gs1: Bool?
	/// Whether to mark the symbol as Reader Initialization.
	/// Serialized only when `true`; `false` is omitted to match the native creator's presence-based semantics.
	public var readerInit: Bool?
	/// Symbol version or size index, depending on the QR variant.
	public var version: Int?
	/// Fixed mask pattern to use when supported.
	public var dataMask: QRCodeDataMask?

	public init(
		errorCorrection: QRCodeErrorCorrection? = nil,
		eci: ECI? = nil,
		gs1: Bool? = nil,
		readerInit: Bool? = nil,
		version: Int? = nil,
		dataMask: QRCodeDataMask? = nil
	) {
		self.errorCorrection = errorCorrection
		self.eci = eci
		self.gs1 = gs1
		self.readerInit = readerInit
		self.version = version
		self.dataMask = dataMask
	}
}

/// Typed creation options for Data Matrix.
public struct DataMatrixOptions: Sendable, Hashable {
	/// Character encoding / ECI designator.
	public var eci: ECI?
	/// Whether the payload is GS1 data.
	/// Serialized only when `true`; `false` is omitted to match the native creator's presence-based semantics.
	public var gs1: Bool?
	/// Whether to mark the symbol as Reader Initialization.
	/// Serialized only when `true`; `false` is omitted to match the native creator's presence-based semantics.
	public var readerInit: Bool?
	/// Whether to force square symbols instead of rectangular ones.
	/// Serialized only when `true`; `false` is omitted to match the native creator's presence-based semantics.
	public var forceSquare: Bool?
	/// Symbol version / size index when supported by the native encoder.
	public var version: Int?

	public init(
		eci: ECI? = nil,
		gs1: Bool? = nil,
		readerInit: Bool? = nil,
		forceSquare: Bool? = nil,
		version: Int? = nil
	) {
		self.eci = eci
		self.gs1 = gs1
		self.readerInit = readerInit
		self.forceSquare = forceSquare
		self.version = version
	}
}

/// Typed creation options for PDF417-family symbols.
public struct PDF417Options: Sendable, Hashable {
	/// Native PDF417 error correction level (`0...8`).
	public var errorCorrectionLevel: PDF417ErrorCorrectionLevel?
	/// Character encoding / ECI designator.
	public var eci: ECI?
	/// Preferred column count.
	public var columns: Int?
	/// Preferred row count.
	public var rows: Int?

	public init(
		errorCorrectionLevel: PDF417ErrorCorrectionLevel? = nil,
		eci: ECI? = nil,
		columns: Int? = nil,
		rows: Int? = nil
	) {
		self.errorCorrectionLevel = errorCorrectionLevel
		self.eci = eci
		self.columns = columns
		self.rows = rows
	}
}

/// Typed creation options for Aztec.
public struct AztecOptions: Sendable, Hashable {
	/// Requested error correction overhead percentage.
	public var errorCorrectionPercent: Int?
	/// Character encoding / ECI designator.
	public var eci: ECI?
	/// Whether the payload is GS1 data.
	/// Serialized only when `true`; `false` is omitted to match the native creator's presence-based semantics.
	public var gs1: Bool?
	/// Whether to mark the symbol as Reader Initialization.
	/// Serialized only when `true`; `false` is omitted to match the native creator's presence-based semantics.
	public var readerInit: Bool?

	public init(
		errorCorrectionPercent: Int? = nil,
		eci: ECI? = nil,
		gs1: Bool? = nil,
		readerInit: Bool? = nil
	) {
		self.errorCorrectionPercent = errorCorrectionPercent
		self.eci = eci
		self.gs1 = gs1
		self.readerInit = readerInit
	}
}

/// Typed creation options for MaxiCode.
public struct MaxiCodeOptions: Sendable, Hashable {
	/// MaxiCode mode (`2...6`).
	public var mode: MaxiCodeMode?
	/// Character encoding / ECI designator.
	public var eci: ECI?

	public init(mode: MaxiCodeMode? = nil, eci: ECI? = nil) {
		self.mode = mode
		self.eci = eci
	}
}

/// Typed creation options for Code 128.
public struct Code128Options: Sendable, Hashable {
	/// Character encoding / ECI designator.
	public var eci: ECI?
	/// Whether the payload is GS1 data.
	/// Serialized only when `true`; `false` is omitted to match the native creator's presence-based semantics.
	public var gs1: Bool?
	/// Whether to mark the symbol as Reader Initialization.
	/// Serialized only when `true`; `false` is omitted to match the native creator's presence-based semantics.
	public var readerInit: Bool?

	public init(eci: ECI? = nil, gs1: Bool? = nil, readerInit: Bool? = nil) {
		self.eci = eci
		self.gs1 = gs1
		self.readerInit = readerInit
	}
}
