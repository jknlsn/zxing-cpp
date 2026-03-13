// Copyright 2026 Axel Waggershauser
// SPDX-License-Identifier: Apache-2.0

import Foundation

/// Low-level typed options for barcode creation, serialized as a JSON string for the C API.
///
/// The underlying C++ `CreatorOptions` accepts options as a string (comma-separated key=value or JSON).
/// This struct provides type-safe properties that are serialized to JSON when passed to the C bridge,
/// so Swift callers do not need to know the underlying JSON keys. Prefer `BarcodeCreationOptions`
/// and its format-specific Swift option structs when possible; use `CreatorOptions` as an escape
/// hatch for bridge options that do not yet have dedicated Swift surface area.
public struct CreatorOptions: Sendable, Hashable {
	/// Symbology-specific error correction or mode setting.
	///
	/// Common values include `"L"`, `"M"`, `"Q"`, `"H"` for QR variants, percentage strings
	/// like `"23%"` for Aztec, and explicit level strings like `"4"` for PDF417.
	public var ecLevel: String?

	/// Extended Channel Interpretation designator.
	///
	/// Pass either a character set name understood by zxing-cpp (for example `"UTF-8"`) or a
	/// numeric ECI designator encoded as a string.
	public var eci: String?

	/// Whether content is GS1-formatted data.
	/// Serialized only when `true`; `false` is omitted to match the native creator's presence-based semantics.
	public var gs1: Bool?


	/// Whether this is a Reader Initialisation symbol.
	/// Serialized only when `true`; `false` is omitted to match the native creator's presence-based semantics.
	public var readerInit: Bool?

	/// Whether to force a square symbol (for Data Matrix, etc.).
	/// Serialized only when `true`; `false` is omitted to match the native creator's presence-based semantics.
	public var forceSquare: Bool?

	/// Number of columns (for PDF417, etc.).
	public var columns: Int?

	/// Number of rows (for PDF417, etc.).
	public var rows: Int?

	/// Symbol version or size index, depending on the symbology.
	public var version: Int?

	/// Data mask pattern for QR variants (`0...7`).
	public var dataMask: Int?

	public init(
		ecLevel: String? = nil,
		eci: String? = nil,
		gs1: Bool? = nil,
		readerInit: Bool? = nil,
		forceSquare: Bool? = nil,
		columns: Int? = nil,
		rows: Int? = nil,
		version: Int? = nil,
		dataMask: Int? = nil
	) {
		self.ecLevel = ecLevel
		self.eci = eci
		self.gs1 = gs1
		self.readerInit = readerInit
		self.forceSquare = forceSquare
		self.columns = columns
		self.rows = rows
		self.version = version
		self.dataMask = dataMask
	}

	/// Serializes the non-nil options to a JSON string for the C API.
	internal func serializedOptions() throws -> String? {
		var object: [String: Any] = [:]
		if let ecLevel {
			object["EcLevel"] = ecLevel
		}
		if let eci {
			object["ECI"] = eci
		}
		if gs1 == true {
			object["GS1"] = true
		}
		if readerInit == true {
			object["ReaderInit"] = true
		}
		if forceSquare == true {
			object["ForceSquare"] = true
		}
		if let columns {
			object["Columns"] = columns
		}
		if let rows {
			object["Rows"] = rows
		}
		if let version {
			object["Version"] = version
		}
		if let dataMask {
			object["DataMask"] = dataMask
		}

		guard !object.isEmpty else { return nil }
		guard JSONSerialization.isValidJSONObject(object) else {
			throw ZXingError("Failed to encode creator options as JSON")
		}

		let data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
		guard let string = String(data: data, encoding: .utf8) else {
			throw ZXingError("Failed to encode creator options as UTF-8 JSON")
		}
		return string
	}
}
