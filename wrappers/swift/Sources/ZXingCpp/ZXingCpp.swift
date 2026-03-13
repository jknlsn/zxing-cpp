// Copyright 2026 Axel Waggershauser
// SPDX-License-Identifier: Apache-2.0

import ZXingCBridge
import Foundation

// MARK: - Error

/// Error type for ZXing operations.
public struct ZXingError: Error, LocalizedError, CustomStringConvertible, Sendable {
	public let message: String
	public var description: String { message }
	public var errorDescription: String? { message }

	init(_ message: String) {
		self.message = message
	}
}

// MARK: - Internal Helpers

private func c2s(_ ptr: UnsafeMutablePointer<CChar>?) -> String {
	guard let ptr else { return "" }
	let str = String(cString: ptr)
	ZXing_free(ptr)
	return str
}

private func c2bytes(_ ptr: UnsafeMutablePointer<UInt8>?, _ len: Int32) -> Data {
	guard let ptr else { return Data() }
	defer { ZXing_free(ptr) }
	guard len > 0 else { return Data() }
	return Data(bytes: ptr, count: Int(len))
}

/// Retrieves the last error from the C library's thread-local error state.
///
/// - Important: call this on the same thread and immediately after a failing C API call.
private func lastError() -> ZXingError {
	if let msg = ZXing_LastErrorMsg() {
		return ZXingError(c2s(msg))
	}
	return ZXingError("Unknown ZXing error")
}

private func checkedInt32(_ value: Int, name: String) throws -> Int32 {
	guard value >= Int(Int32.min), value <= Int(Int32.max) else {
		throw ZXingError("\(name) exceeds the supported Int32 range")
	}
	return Int32(value)
}

private func checkedUInt8BackedInt(_ value: Int, name: String) throws -> Int32 {
	guard value >= 0, value <= Int(UInt8.max) else {
		throw ZXingError("\(name) must be in 0...255")
	}
	return Int32(value)
}

private func unknownCEnumError<T>(_ raw: Int32, type: T.Type = T.self) -> ZXingError {
	ZXingError(
		"Unknown C enum value \(raw) for \(T.self). This may indicate a version mismatch between the Swift wrapper and the native ZXing library."
	)
}

/// Bridge our Int32-based Swift types to/from C enum types (imported with UInt32 rawValue).
private func cEnum<T: RawRepresentable>(_ v: Int32) -> T? where T.RawValue == UInt32 {
	T(rawValue: UInt32(bitPattern: v))
}

private func checkedCEnum<T: RawRepresentable>(_ v: Int32) throws -> T where T.RawValue == UInt32 {
	guard let result: T = cEnum(v) else { throw unknownCEnumError(v, type: T.self) }
	return result
}

private func sEnum<T: RawRepresentable>(_ v: T) -> Int32 where T.RawValue == UInt32 {
	Int32(bitPattern: v.rawValue)
}

private func swiftEnum<T: RawRepresentable>(_ raw: Int32) -> T? where T.RawValue == Int32 {
	T(rawValue: raw)
}

private func checkedSwiftEnum<T: RawRepresentable>(_ raw: Int32) throws -> T where T.RawValue == Int32 {
	guard let result: T = swiftEnum(raw) else { throw unknownCEnumError(raw, type: T.self) }
	return result
}

/// Returns the native zxing-cpp library version string.
public func version() -> String {
	guard let v = ZXing_Version() else { return "" }
	return String(cString: v)
}

// MARK: - BarcodeFormat

/// Represents a barcode format/symbology.
///
/// Can represent a specific format (e.g., `.qrCode`) or a filter for multiple formats (e.g., `.allReadable`).
public struct BarcodeFormat: RawRepresentable, Hashable, Sendable, CustomStringConvertible {
	public let rawValue: Int32
	public init(rawValue: Int32) { self.rawValue = rawValue }

	fileprivate var cValue: ZXing_BarcodeFormat {
		ZXing_BarcodeFormat(rawValue: UInt32(bitPattern: rawValue))
	}

	fileprivate var resolvedName: String {
		c2s(ZXing_BarcodeFormatToString(cValue))
	}

	fileprivate var isKnown: Bool {
		let name = resolvedName
		return !name.isEmpty && name != "Unknown"
	}

	/// A human-readable name for this format (e.g., "QRCode").
	///
	/// - Note: Each access allocates through the C bridge. Cache the result in hot paths.
	public var description: String {
		let name = resolvedName
		return name.isEmpty || name == "Unknown" ? "Unknown BarcodeFormat(\(rawValue))" : name
	}

	/// The base symbology for this format (e.g., `.ean13` returns `.eanUPC`).
	public var symbology: BarcodeFormat {
		guard isKnown else { return self }
		return BarcodeFormat(rawValue: sEnum(ZXing_BarcodeFormatSymbology(cValue)))
	}

	/// Parses a format name string into a `BarcodeFormat`. Returns `nil` on failure.
	public init?(string: String) {
		let value = ZXing_BarcodeFormatFromString(string)
		if sEnum(value) == BarcodeFormat.invalid.rawValue { return nil }
		self.rawValue = sEnum(value)
	}


	// Filter constants
	public static let invalid           = BarcodeFormat(rawValue: 0xFFFF)
	public static let none              = BarcodeFormat(rawValue: 0x0000)
	public static let all               = BarcodeFormat(rawValue: 0x2A2A)
	public static let allReadable       = BarcodeFormat(rawValue: 0x722A)
	public static let allCreatable      = BarcodeFormat(rawValue: 0x772A)
	public static let allLinear         = BarcodeFormat(rawValue: 0x6C2A)
	public static let allMatrix         = BarcodeFormat(rawValue: 0x6D2A)
	public static let allGS1            = BarcodeFormat(rawValue: 0x472A)
	public static let allRetail         = BarcodeFormat(rawValue: 0x522A)
	public static let allIndustrial     = BarcodeFormat(rawValue: 0x492A)

	// DataBar
	public static let dataBar           = BarcodeFormat(rawValue: 0x2065)
	public static let dataBarOmni       = BarcodeFormat(rawValue: 0x6F65)
	public static let dataBarStk        = BarcodeFormat(rawValue: 0x7365)
	public static let dataBarStkOmni    = BarcodeFormat(rawValue: 0x4F65)
	public static let dataBarLtd        = BarcodeFormat(rawValue: 0x6C65)
	public static let dataBarExp        = BarcodeFormat(rawValue: 0x6565)
	public static let dataBarExpStk     = BarcodeFormat(rawValue: 0x4565)

	// EAN/UPC
	public static let eanUPC            = BarcodeFormat(rawValue: 0x2045)
	public static let ean13             = BarcodeFormat(rawValue: 0x3145)
	public static let ean8              = BarcodeFormat(rawValue: 0x3845)
	public static let ean5              = BarcodeFormat(rawValue: 0x3545)
	public static let ean2              = BarcodeFormat(rawValue: 0x3245)
	public static let isbn              = BarcodeFormat(rawValue: 0x6945)
	public static let upcA              = BarcodeFormat(rawValue: 0x6145)
	public static let upcE              = BarcodeFormat(rawValue: 0x6545)

	// Code39
	public static let code39            = BarcodeFormat(rawValue: 0x2041)
	public static let code39Std         = BarcodeFormat(rawValue: 0x7341)
	public static let code39Ext         = BarcodeFormat(rawValue: 0x6541)
	public static let code32            = BarcodeFormat(rawValue: 0x3241)
	public static let pzn               = BarcodeFormat(rawValue: 0x7041)

	// Other linear
	public static let codabar           = BarcodeFormat(rawValue: 0x2046)
	public static let code93            = BarcodeFormat(rawValue: 0x2047)
	public static let code128           = BarcodeFormat(rawValue: 0x2043)
	public static let itf               = BarcodeFormat(rawValue: 0x2049)
	public static let itf14             = BarcodeFormat(rawValue: 0x3449)
	public static let otherBarcode      = BarcodeFormat(rawValue: 0x2058)
	public static let dxFilmEdge        = BarcodeFormat(rawValue: 0x7858)

	// PDF417
	public static let pdf417            = BarcodeFormat(rawValue: 0x204C)
	public static let compactPDF417     = BarcodeFormat(rawValue: 0x634C)
	public static let microPDF417       = BarcodeFormat(rawValue: 0x6D4C)

	// Aztec
	public static let aztec             = BarcodeFormat(rawValue: 0x207A)
	public static let aztecCode         = BarcodeFormat(rawValue: 0x637A)
	public static let aztecRune         = BarcodeFormat(rawValue: 0x727A)

	// QR Code
	public static let qrCode            = BarcodeFormat(rawValue: 0x2051)
	public static let qrCodeModel1      = BarcodeFormat(rawValue: 0x3151)
	public static let qrCodeModel2      = BarcodeFormat(rawValue: 0x3251)
	public static let microQRCode       = BarcodeFormat(rawValue: 0x6D51)
	public static let rmqrCode          = BarcodeFormat(rawValue: 0x7251)

	// Other matrix
	public static let dataMatrix        = BarcodeFormat(rawValue: 0x2064)
	public static let maxiCode          = BarcodeFormat(rawValue: 0x2055)
}

extension BarcodeFormat {
	/// Returns individual formats matching the given filter.
	public static func all(matching filter: BarcodeFormat = .all) -> [BarcodeFormat] {
		guard filter.isKnown else { return [] }
		var count: Int32 = 0
		guard let ptr = ZXing_BarcodeFormatsList(filter.cValue, &count) else { return [] }
		defer { ZXing_free(ptr) }
		guard count > 0 else { return [] }
		return (0..<Int(count)).map { BarcodeFormat(rawValue: sEnum(ptr[$0])) }
	}

	/// Parses a comma-separated string of format names into an array of `BarcodeFormat`. Returns `nil` on failure.
	public static func formats(from string: String) -> [BarcodeFormat]? {
		var count: Int32 = 0
		let ptr = string.withCString { ZXing_BarcodeFormatsFromString($0, &count) }
		defer {
			if let ptr {
				ZXing_free(ptr)
			}
		}
		if let ptr, count > 0 {
			return (0..<Int(count)).map { BarcodeFormat(rawValue: sEnum(ptr[$0])) }
		} else if let msg = ZXing_LastErrorMsg() {
			ZXing_free(msg)
			return nil
		} else {
			return []
		}
	}
}

private func checkedBarcodeFormat(_ format: BarcodeFormat) throws -> ZXing_BarcodeFormat {
	guard format.isKnown else { throw unknownCEnumError(format.rawValue, type: BarcodeFormat.self) }
	return format.cValue
}

private extension Array where Element == BarcodeFormat {
	func withCFormats<T>(_ body: (UnsafePointer<ZXing_BarcodeFormat>?, Int32) throws -> T) throws -> T {
		let raw: [ZXing_BarcodeFormat] = try map(checkedBarcodeFormat)
		return try raw.withUnsafeBufferPointer { buf in
			try body(buf.baseAddress, Int32(buf.count))
		}
	}
}

// MARK: - Enums

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

// MARK: - Point & Position

public struct Point: Hashable, Sendable, CustomStringConvertible {
	public var x: Int
	public var y: Int

	public var description: String { "\(x)x\(y)" }

	public init(x: Int, y: Int) { self.x = x; self.y = y }

	init(_ p: ZXing_PointI) { x = Int(p.x); y = Int(p.y) }
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

// MARK: - ImageView

/// A non-owning immutable view into image pixel data for barcode detection.
///
/// `ImageView` is intentionally **not** `Sendable`. It holds a non-owning pointer into external
/// pixel data whose lifetime is managed by the caller. Sharing an `ImageView` across concurrency
/// domains could lead to use-after-free if the backing data is deallocated on another thread.
/// Confine each `ImageView` to a single task or serial context.
public final class ImageView: CustomDebugStringConvertible {
	internal let _handle: OpaquePointer
	private let _retainedSource: AnyObject?

	internal init(_ handle: OpaquePointer, retaining source: AnyObject?) {
		_handle = handle
		_retainedSource = source
	}

	private static func makeHandle(
		pointer: UnsafePointer<UInt8>?, size: Int, width: Int, height: Int, format: ImageFormat, rowStride: Int, pixStride: Int
	) throws -> OpaquePointer {
		let cSize = try checkedInt32(size, name: "ImageView size")
		let cWidth = try checkedInt32(width, name: "ImageView width")
		let cHeight = try checkedInt32(height, name: "ImageView height")
		let cRowStride = try checkedInt32(rowStride, name: "ImageView rowStride")
		let cPixStride = try checkedInt32(pixStride, name: "ImageView pixStride")
		let cFormat: ZXing_ImageFormat = try checkedCEnum(format.rawValue)
		guard let iv = ZXing_ImageView_new_checked(
			pointer, cSize, cWidth, cHeight, cFormat, cRowStride, cPixStride
		) else {
			throw lastError()
		}
		return iv
	}

	/// Creates an ImageView from Data without additional pixel buffer copying.
	public convenience init( data: Data, width: Int, height: Int, format: ImageFormat, rowStride: Int = 0, pixStride: Int = 0) throws {
		let nsData = data as NSData
		let pointer: UnsafePointer<UInt8>? = nsData.length > 0
			? nsData.bytes.bindMemory(to: UInt8.self, capacity: nsData.length)
			: nil
		let handle = try Self.makeHandle(
			pointer: pointer,
			size: nsData.length,
			width: width,
			height: height,
			format: format,
			rowStride: rowStride,
			pixStride: pixStride
		)
		self.init(handle, retaining: nsData)
	}

	/// Creates an ImageView from an external data source. The source is retained to keep the pointer valid.
	public convenience init(
		pointer: UnsafePointer<UInt8>, size: Int, width: Int, height: Int, format: ImageFormat,
		rowStride: Int = 0, pixStride: Int = 0, retaining source: AnyObject
	) throws {
		let handle = try Self.makeHandle(
			pointer: pointer, size: size, width: width, height: height, format: format, rowStride: rowStride, pixStride: pixStride)
		self.init(handle, retaining: source)
	}

	private var derivedRetainedSource: AnyObject {
		_retainedSource ?? self
	}

	public var debugDescription: String {
		"ImageView(retaining: \(_retainedSource.map { "\(type(of: $0))" } ?? "nil"))"
	}

	deinit {
		ZXing_ImageView_delete(_handle)
	}

	/// Returns a cropped image view for the given rectangle.
	///
	/// This is a zero-copy operation that returns a new `ImageView` while sharing the same
	/// underlying pixel buffer. Only pointer/stride metadata changes; the pixel buffer is not modified.
	public func cropped(left: Int, top: Int, width: Int, height: Int) throws -> ImageView {
		let cLeft = try checkedInt32(left, name: "crop left")
		let cTop = try checkedInt32(top, name: "crop top")
		let cWidth = try checkedInt32(width, name: "crop width")
		let cHeight = try checkedInt32(height, name: "crop height")
		guard let handle = ZXing_ImageView_cropped(_handle, cLeft, cTop, cWidth, cHeight) else {
			throw lastError()
		}
		return ImageView(handle, retaining: derivedRetainedSource)
	}

	/// Returns a rotated image view (degrees must be a multiple of 90).
	///
	/// This is a zero-copy operation that returns a new `ImageView` while sharing the same
	/// underlying pixel buffer. Only pointer/stride metadata changes; the pixel buffer is not modified.
	public func rotated(by degrees: Int) throws -> ImageView {
		let cDegrees = try checkedInt32(degrees, name: "rotation")
		guard let handle = ZXing_ImageView_rotated(_handle, cDegrees) else {
			throw lastError()
		}
		return ImageView(handle, retaining: derivedRetainedSource)
	}
}

// MARK: - Image

/// An owned image returned by barcode writing operations.
///
/// `@unchecked Sendable` safety rationale: The underlying C++ `Image` class owns its pixel data
/// via `std::unique_ptr<uint8_t[]>` and is immutable after construction. All C API accessors
/// (`ZXing_Image_width`, `_height`, `_format`, `_data`) take `const ZXing_Image*` and perform
/// no mutation, making concurrent reads safe.
public final class Image: @unchecked Sendable, CustomDebugStringConvertible {
	internal let _handle: OpaquePointer

	internal init(_ handle: OpaquePointer) { _handle = handle }

	deinit { ZXing_Image_delete(_handle) }

	public var width: Int { Int(ZXing_Image_width(_handle)) }
	public var height: Int { Int(ZXing_Image_height(_handle)) }
	public var format: ImageFormat { swiftEnum(sEnum(ZXing_Image_format(_handle))) ?? .none }
	public var debugDescription: String {
		"Image(\(width)x\(height), format: \(format))"
	}

	/// The raw pixel data as a copy.
	///
	/// - Note: Each access copies `width * height * format.bytesPerPixel` bytes from the
	///   underlying C image. Cache the result if you need to access it multiple times.
	public var data: Data {
		guard let ptr = ZXing_Image_data(_handle) else { return Data() }
		return Data(bytes: ptr, count: width * height * format.bytesPerPixel)
	}
}

// MARK: - WriterOptions

/// Options for rendering barcodes to images or SVG.
public struct WriterOptions: Sendable, Hashable {
	/// Scaling factor (>0: pixels per module, <0: target size in pixels).
	public var scale: Int

	/// Rotation in degrees (0, 90, 180, or 270).
	public var rotate: Int

	/// Whether to add human-readable text below linear barcodes.
	public var humanReadableText: Bool

	/// Add quiet zones (white margins) around the barcode.
	public var addQuietZones: Bool

	/// Default values queried once from the C++ library at startup.
	fileprivate static let cDefaults: (scale: Int, rotate: Int, humanReadableText: Bool, addQuietZones: Bool) = {
		guard let handle = ZXing_WriterOptions_new() else {
			// Allocation failure at static init is unrecoverable; fall back to known C++ defaults.
			return (scale: 1, rotate: 0, humanReadableText: false, addQuietZones: true)
		}
		defer { ZXing_WriterOptions_delete(handle) }
		return (
			scale: Int(ZXing_WriterOptions_getScale(handle)),
			rotate: Int(ZXing_WriterOptions_getRotate(handle)),
			humanReadableText: ZXing_WriterOptions_getAddHRT(handle),
			addQuietZones: ZXing_WriterOptions_getAddQuietZones(handle)
		)
	}()

	public init() {
		self.init(
			scale: Self.cDefaults.scale,
			rotate: Self.cDefaults.rotate,
			humanReadableText: Self.cDefaults.humanReadableText,
			addQuietZones: Self.cDefaults.addQuietZones
		)
	}

	public init(
		scale: Int? = nil,
		rotate: Int? = nil,
		humanReadableText: Bool? = nil,
		addQuietZones: Bool? = nil
	) {
		self.scale = scale ?? Self.cDefaults.scale
		self.rotate = rotate ?? Self.cDefaults.rotate
		self.humanReadableText = humanReadableText ?? Self.cDefaults.humanReadableText
		self.addQuietZones = addQuietZones ?? Self.cDefaults.addQuietZones
	}
}

private func withCWriterOptions<T>(_ options: WriterOptions, _ body: (OpaquePointer) throws -> T) throws -> T {
	guard let handle = ZXing_WriterOptions_new() else { throw lastError() }
	defer { ZXing_WriterOptions_delete(handle) }

	ZXing_WriterOptions_setScale(handle, try checkedInt32(options.scale, name: "WriterOptions.scale"))
	ZXing_WriterOptions_setRotate(handle, try checkedInt32(options.rotate, name: "WriterOptions.rotate"))
	ZXing_WriterOptions_setAddHRT(handle, options.humanReadableText)
	ZXing_WriterOptions_setAddQuietZones(handle, options.addQuietZones)

	return try body(handle)
}

// MARK: - CreatorOptions

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

/// High-level typed barcode-creation configuration.
///
/// Prefer these format-specific cases for discoverability and autocomplete. Use `.raw` to pass the
/// low-level `CreatorOptions` struct directly, or `.rawString` to supply an arbitrary native option
/// payload unchanged.
public struct BarcodeCreationOptions: Sendable, Hashable {
	private enum Storage: Sendable, Hashable {
		case qrCode(QRCodeOptions)
		case qrCodeModel2(QRCodeOptions)
		case microQRCode(QRCodeOptions)
		case rmqrCode(QRCodeOptions)
		case dataMatrix(DataMatrixOptions)
		case pdf417(PDF417Options)
		case compactPDF417(PDF417Options)
		case microPDF417(PDF417Options)
		case aztec(AztecOptions)
		case maxiCode(MaxiCodeOptions)
		case code128(Code128Options)
		case raw(format: BarcodeFormat, options: CreatorOptions)
		case rawString(format: BarcodeFormat, payload: String)
	}

	private let storage: Storage

	private init(_ storage: Storage) {
		self.storage = storage
	}

	public static func qrCode(_ options: QRCodeOptions = .init()) -> Self {
		.init(.qrCode(options))
	}

	public static func qrCodeModel2(_ options: QRCodeOptions = .init()) -> Self {
		.init(.qrCodeModel2(options))
	}

	public static func microQRCode(_ options: QRCodeOptions = .init()) -> Self {
		.init(.microQRCode(options))
	}

	public static func rmqrCode(_ options: QRCodeOptions = .init()) -> Self {
		.init(.rmqrCode(options))
	}

	public static func dataMatrix(_ options: DataMatrixOptions = .init()) -> Self {
		.init(.dataMatrix(options))
	}

	public static func pdf417(_ options: PDF417Options = .init()) -> Self {
		.init(.pdf417(options))
	}

	public static func compactPDF417(_ options: PDF417Options = .init()) -> Self {
		.init(.compactPDF417(options))
	}

	public static func microPDF417(_ options: PDF417Options = .init()) -> Self {
		.init(.microPDF417(options))
	}

	public static func aztec(_ options: AztecOptions = .init()) -> Self {
		.init(.aztec(options))
	}

	public static func maxiCode(_ options: MaxiCodeOptions = .init()) -> Self {
		.init(.maxiCode(options))
	}

	public static func code128(_ options: Code128Options = .init()) -> Self {
		.init(.code128(options))
	}

	public static func raw(format: BarcodeFormat, options: CreatorOptions) -> Self {
		.init(.raw(format: format, options: options))
	}

	public static func rawString(format: BarcodeFormat, payload: String) -> Self {
		.init(.rawString(format: format, payload: payload))
	}

	internal var format: BarcodeFormat {
		switch storage {
		case .qrCode:
			return .qrCode
		case .qrCodeModel2:
			return .qrCodeModel2
		case .microQRCode:
			return .microQRCode
		case .rmqrCode:
			return .rmqrCode
		case .dataMatrix:
			return .dataMatrix
		case .pdf417:
			return .pdf417
		case .compactPDF417:
			return .compactPDF417
		case .microPDF417:
			return .microPDF417
		case .aztec:
			return .aztec
		case .maxiCode:
			return .maxiCode
		case .code128:
			return .code128
		case .raw(let format, _):
			return format
		case .rawString(let format, _):
			return format
		}
	}

	internal func serializedOptions() throws -> String? {
		switch storage {
		case .qrCode(let options), .qrCodeModel2(let options), .microQRCode(let options), .rmqrCode(let options):
			return try options.creatorOptions().serializedOptions()
		case .dataMatrix(let options):
			return try options.creatorOptions().serializedOptions()
		case .pdf417(let options), .compactPDF417(let options), .microPDF417(let options):
			return try options.creatorOptions().serializedOptions()
		case .aztec(let options):
			return try options.creatorOptions().serializedOptions()
		case .maxiCode(let options):
			return try options.creatorOptions().serializedOptions()
		case .code128(let options):
			return try options.creatorOptions().serializedOptions()
		case .raw(_, let options):
			return try options.serializedOptions()
		case .rawString(_, let payload):
			return payload
		}
	}
}

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

private extension QRCodeOptions {
	func creatorOptions() throws -> CreatorOptions {
		CreatorOptions(
			ecLevel: errorCorrection?.rawValue,
			eci: try eci?.serializedValue(),
			gs1: gs1,
			readerInit: readerInit,
			version: version,
			dataMask: dataMask?.rawValue
		)
	}
}

private extension DataMatrixOptions {
	func creatorOptions() throws -> CreatorOptions {
		CreatorOptions(
			eci: try eci?.serializedValue(),
			gs1: gs1,
			readerInit: readerInit,
			forceSquare: forceSquare,
			version: version
		)
	}
}

private extension PDF417Options {
	func creatorOptions() throws -> CreatorOptions {
		CreatorOptions(
			ecLevel: errorCorrectionLevel.map { String($0.rawValue) },
			eci: try eci?.serializedValue(),
			columns: columns,
			rows: rows
		)
	}
}

private extension AztecOptions {
	func creatorOptions() throws -> CreatorOptions {
		CreatorOptions(
			ecLevel: errorCorrectionPercent.map { "\($0)%" },
			eci: try eci?.serializedValue(),
			gs1: gs1,
			readerInit: readerInit
		)
	}
}

private extension MaxiCodeOptions {
	func creatorOptions() throws -> CreatorOptions {
		CreatorOptions(
			ecLevel: mode.map { String($0.rawValue) },
			eci: try eci?.serializedValue()
		)
	}
}

private extension Code128Options {
	func creatorOptions() throws -> CreatorOptions {
		CreatorOptions(
			eci: try eci?.serializedValue(),
			gs1: gs1,
			readerInit: readerInit
		)
	}
}

// MARK: - Barcode

private final class NativeBarcodeStorage: @unchecked Sendable {
	// The underlying native barcode object is immutable for read access, but zint-backed rendering
	// mutates shared scratch buffers behind the `const Barcode&` API. Serialize all native handle
	// access so copied Swift `Barcode` values remain safe to use across concurrency domains.
	private let handle: OpaquePointer
	private let lock = NSLock()

	init(_ handle: OpaquePointer) {
		self.handle = handle
	}

	deinit {
		ZXing_Barcode_delete(handle)
	}

	func metadata(forKey key: String) -> String {
		lock.lock()
		defer { lock.unlock() }
		return key.withCString { c2s(ZXing_Barcode_extra(handle, $0)) }
	}

	func toSVG(_ options: WriterOptions) throws -> String {
		lock.lock()
		defer { lock.unlock() }

		return try withCWriterOptions(options) { optionsHandle in
			guard let ptr = ZXing_WriteBarcodeToSVG(handle, optionsHandle) else { throw lastError() }
			return c2s(ptr)
		}
	}

	func toImage(_ options: WriterOptions) throws -> Image {
		lock.lock()
		defer { lock.unlock() }

		return try withCWriterOptions(options) { optionsHandle in
			guard let ptr = ZXing_WriteBarcodeToImage(handle, optionsHandle) else { throw lastError() }
			return Image(ptr)
		}
	}
}

/// A decoded or created barcode snapshot.
///
/// `Barcode` is a Swift value type. All public fields are copied out of the native barcode object
/// during initialization so equality and hashing reflect barcode contents rather than pointer
/// identity.
///
/// `Barcode` is `Sendable`: the public state is immutable Swift data, and the retained native
/// handle is used only for rendering and keyed metadata lookup. Those native operations are
/// serialized internally because zint-backed rendering mutates shared scratch state behind the
/// native `const Barcode&` API.
public struct Barcode: Sendable, Hashable, CustomDebugStringConvertible {
	private let storage: NativeBarcodeStorage
	private let metadataJSON: String

	/// Whether the barcode was successfully decoded or created.
	public let isValid: Bool

	/// The barcode format (e.g., `.qrCode`, `.ean13`).
	public let format: BarcodeFormat

	/// The base symbology (e.g., `.ean13` returns `.eanUPC`).
	public let symbology: BarcodeFormat

	/// The content type of the decoded data.
	public let contentType: ContentType

	/// The decoded text content.
	public let text: String

	/// The raw decoded bytes.
	public let bytes: Data

	/// The decoded bytes with ECI markers included.
	public let bytesECI: Data

	/// ISO/IEC 15424 symbology identifier (e.g., `]Q1` for QR Code).
	public let symbologyIdentifier: String

	/// Corner points of the barcode in the image.
	public let position: Position

	/// Detected rotation in degrees.
	public let orientation: Int

	/// Whether the barcode uses Extended Channel Interpretation.
	public let hasECI: Bool

	/// Whether the barcode was detected as light-on-dark.
	public let isInverted: Bool

	/// Whether the barcode was detected as mirrored.
	public let isMirrored: Bool

	/// Number of detected scan lines (for linear barcodes).
	public let lineCount: Int

	/// Index of this barcode in a structured append sequence.
	public let sequenceIndex: Int

	/// Total number of barcodes in a structured append sequence.
	public let sequenceSize: Int

	/// Identifier of the structured append sequence.
	public let sequenceId: String

	/// The error type if decoding encountered an issue.
	public let errorType: ErrorType

	/// The error message if decoding encountered an issue.
	public let errorMessage: String

	internal init(_ handle: OpaquePointer) throws {
		storage = NativeBarcodeStorage(handle)
		isValid = ZXing_Barcode_isValid(handle)
		format = BarcodeFormat(rawValue: sEnum(ZXing_Barcode_format(handle)))
		symbology = BarcodeFormat(rawValue: sEnum(ZXing_Barcode_symbology(handle)))
		contentType = try checkedSwiftEnum(sEnum(ZXing_Barcode_contentType(handle)))
		text = c2s(ZXing_Barcode_text(handle))
		var bytesLen: Int32 = 0
		bytes = c2bytes(ZXing_Barcode_bytes(handle, &bytesLen), bytesLen)
		var bytesECILen: Int32 = 0
		bytesECI = c2bytes(ZXing_Barcode_bytesECI(handle, &bytesECILen), bytesECILen)
		symbologyIdentifier = c2s(ZXing_Barcode_symbologyIdentifier(handle))
		position = Position(ZXing_Barcode_position(handle))
		orientation = Int(ZXing_Barcode_orientation(handle))
		hasECI = ZXing_Barcode_hasECI(handle)
		isInverted = ZXing_Barcode_isInverted(handle)
		isMirrored = ZXing_Barcode_isMirrored(handle)
		lineCount = Int(ZXing_Barcode_lineCount(handle))
		sequenceIndex = Int(ZXing_Barcode_sequenceIndex(handle))
		sequenceSize = Int(ZXing_Barcode_sequenceSize(handle))
		sequenceId = c2s(ZXing_Barcode_sequenceId(handle))
		errorType = try checkedSwiftEnum(sEnum(ZXing_Barcode_errorType(handle)))
		errorMessage = c2s(ZXing_Barcode_errorMsg(handle))
		metadataJSON = c2s(ZXing_Barcode_extra(handle, nil))
	}

	/// Creates a barcode from text content.
	public init(_ text: String, format: BarcodeFormat, options: String? = nil) throws {
		let cFormat = try checkedBarcodeFormat(format)
		guard let opts = ZXing_CreatorOptions_new(cFormat) else { throw lastError() }
		defer { ZXing_CreatorOptions_delete(opts) }
		if let options {
			options.withCString { ZXing_CreatorOptions_setOptions(opts, $0) }
		}
		let utf8 = text.utf8CString
		let size = try checkedInt32(utf8.count - 1, name: "Text barcode input")
		guard let bc = utf8.withUnsafeBufferPointer({ buffer in
			ZXing_CreateBarcodeFromText(
				buffer.baseAddress,
				size,
				opts
			)
		}) else { throw lastError() }
		self = try Barcode(bc)
	}

	/// Creates a barcode from text content with typed creator options.
	public init(_ text: String, format: BarcodeFormat, options: CreatorOptions) throws {
		try self.init(text, format: format, options: options.serializedOptions())
	}

	/// Creates a barcode from text content using format-specific Swift creation options.
	public init(_ text: String, options: BarcodeCreationOptions) throws {
		try self.init(text, format: options.format, options: options.serializedOptions())
	}

	/// Creates a barcode from binary data.
	public init(bytes: Data, format: BarcodeFormat, options: String? = nil) throws {
		guard bytes.count <= Int(Int32.max) else {
			throw ZXingError("Binary barcode input exceeds maximum supported size")
		}
		let cFormat = try checkedBarcodeFormat(format)
		guard let opts = ZXing_CreatorOptions_new(cFormat) else { throw lastError() }
		defer { ZXing_CreatorOptions_delete(opts) }
		if let options {
			options.withCString { ZXing_CreatorOptions_setOptions(opts, $0) }
		}
		let bc = bytes.withUnsafeBytes { buffer in
			ZXing_CreateBarcodeFromBytes(buffer.baseAddress, Int32(buffer.count), opts)
		}
		guard let bc else { throw lastError() }
		self = try Barcode(bc)
	}

	/// Creates a barcode from binary data with typed creator options.
	public init(bytes: Data, format: BarcodeFormat, options: CreatorOptions) throws {
		try self.init(bytes: bytes, format: format, options: options.serializedOptions())
	}

	/// Creates a barcode from binary data using format-specific Swift creation options.
	public init(bytes: Data, options: BarcodeCreationOptions) throws {
		try self.init(bytes: bytes, format: options.format, options: options.serializedOptions())
	}

	/// Additional format-specific metadata as a JSON string.
	/// - Parameter key: Optional key to retrieve a specific value. Pass `nil` for the full JSON object.
	public func metadata(forKey key: String? = nil) -> String {
		guard let key else { return metadataJSON }
		return storage.metadata(forKey: key)
	}

	/// Renders the barcode as an SVG string.
	public func toSVG(_ options: WriterOptions = .init()) throws -> String {
		try storage.toSVG(options)
	}

	/// Renders the barcode as a grayscale image.
	public func toImage(_ options: WriterOptions = .init()) throws -> Image {
		try storage.toImage(options)
	}

	public static func == (lhs: Barcode, rhs: Barcode) -> Bool {
		lhs.isValid == rhs.isValid &&
		lhs.format == rhs.format &&
		lhs.symbology == rhs.symbology &&
		lhs.contentType == rhs.contentType &&
		lhs.text == rhs.text &&
		lhs.bytes == rhs.bytes &&
		lhs.bytesECI == rhs.bytesECI &&
		lhs.symbologyIdentifier == rhs.symbologyIdentifier &&
		lhs.position == rhs.position &&
		lhs.orientation == rhs.orientation &&
		lhs.hasECI == rhs.hasECI &&
		lhs.isInverted == rhs.isInverted &&
		lhs.isMirrored == rhs.isMirrored &&
		lhs.lineCount == rhs.lineCount &&
		lhs.sequenceIndex == rhs.sequenceIndex &&
		lhs.sequenceSize == rhs.sequenceSize &&
		lhs.sequenceId == rhs.sequenceId &&
		lhs.errorType == rhs.errorType &&
		lhs.errorMessage == rhs.errorMessage &&
		lhs.metadataJSON == rhs.metadataJSON
	}

	public func hash(into hasher: inout Hasher) {
		hasher.combine(isValid)
		hasher.combine(format)
		hasher.combine(symbology)
		hasher.combine(contentType)
		hasher.combine(text)
		hasher.combine(bytes)
		hasher.combine(bytesECI)
		hasher.combine(symbologyIdentifier)
		hasher.combine(position)
		hasher.combine(orientation)
		hasher.combine(hasECI)
		hasher.combine(isInverted)
		hasher.combine(isMirrored)
		hasher.combine(lineCount)
		hasher.combine(sequenceIndex)
		hasher.combine(sequenceSize)
		hasher.combine(sequenceId)
		hasher.combine(errorType)
		hasher.combine(errorMessage)
		hasher.combine(metadataJSON)
	}

	public var debugDescription: String {
		"Barcode(format: \(format), text: \"\(text.prefix(50))\(text.count > 50 ? "..." : "")\")"
	}
}

// MARK: - BarcodeReader

/// Barcode reader with configurable detection options.
///
/// Usage:
/// ```swift
/// let config = BarcodeReader.Configuration(formats: [.qrCode, .ean13], returnErrors: true)
/// let reader = BarcodeReader(configuration: config)
/// let barcodes = try reader.read(from: imageView)
/// ```
public struct BarcodeReader: Sendable, CustomDebugStringConvertible {
	public struct Configuration: Sendable, Hashable {
		/// Barcode formats to search for. Empty means all supported formats.
		/// Order and duplicates do not affect behavior.
		public var formats: [BarcodeFormat]

		/// Spend more time to find barcodes; slower but more accurate.
		public var tryHarder: Bool

		/// Also detect barcodes in 90/180/270 degree rotated images.
		public var tryRotate: Bool

		/// Also try detecting inverted (white on black) barcodes.
		public var tryInvert: Bool

		/// Try downscaled images (high resolution images can hamper detection).
		public var tryDownscale: Bool

		/// Assume the image contains only a single, perfectly aligned barcode.
		public var isPure: Bool

		/// Return invalid barcodes with error information instead of skipping them.
		public var returnErrors: Bool

		/// The binarization algorithm for converting grayscale to black/white.
		public var binarizer: Binarizer

		/// Text encoding mode for converting barcode content bytes to strings.
		public var textMode: TextMode

		/// Fallback character set to use when encoding metadata is absent or ambiguous.
		public var characterSet: CharacterSet

		/// Minimum number of lines for linear barcodes.
		public var minLineCount: Int

		/// Maximum number of symbols to detect.
		public var maxNumberOfSymbols: Int

		/// Handling of EAN-2/EAN-5 Add-On symbols.
		public var eanAddOnSymbol: EanAddOnSymbol

		/// Validate optional checksums (e.g., Code39, ITF).
		public var validateOptionalChecksum: Bool

		/// Default values queried once from the C++ library at startup.
		fileprivate static let cDefaults: (
			tryHarder: Bool, tryRotate: Bool, tryInvert: Bool, tryDownscale: Bool,
			isPure: Bool, returnErrors: Bool, binarizer: Binarizer, textMode: TextMode, characterSet: CharacterSet,
			minLineCount: Int, maxNumberOfSymbols: Int, eanAddOnSymbol: EanAddOnSymbol,
			validateOptionalChecksum: Bool
		) = {
			guard let handle = ZXing_ReaderOptions_new() else {
				// Allocation failure at static init is unrecoverable; fall back to known C++ defaults.
				return (
					tryHarder: true, tryRotate: true, tryInvert: true, tryDownscale: true,
					isPure: false, returnErrors: false, binarizer: .localAverage, textMode: .hri, characterSet: .unknown,
					minLineCount: 2, maxNumberOfSymbols: 255, eanAddOnSymbol: .ignore,
					validateOptionalChecksum: false
				)
			}
			defer { ZXing_ReaderOptions_delete(handle) }
			return (
				tryHarder: ZXing_ReaderOptions_getTryHarder(handle),
				tryRotate: ZXing_ReaderOptions_getTryRotate(handle),
				tryInvert: ZXing_ReaderOptions_getTryInvert(handle),
				tryDownscale: ZXing_ReaderOptions_getTryDownscale(handle),
				isPure: ZXing_ReaderOptions_getIsPure(handle),
				returnErrors: ZXing_ReaderOptions_getReturnErrors(handle),
				binarizer: swiftEnum(sEnum(ZXing_ReaderOptions_getBinarizer(handle))) ?? .localAverage,
				textMode: swiftEnum(sEnum(ZXing_ReaderOptions_getTextMode(handle))) ?? .hri,
				characterSet: swiftEnum(sEnum(ZXing_ReaderOptions_getCharacterSet(handle))) ?? .unknown,
				minLineCount: Int(ZXing_ReaderOptions_getMinLineCount(handle)),
				maxNumberOfSymbols: Int(ZXing_ReaderOptions_getMaxNumberOfSymbols(handle)),
				eanAddOnSymbol: swiftEnum(sEnum(ZXing_ReaderOptions_getEanAddOnSymbol(handle))) ?? .ignore,
				validateOptionalChecksum: ZXing_ReaderOptions_getValidateOptionalChecksum(handle)
			)
		}()

		public init(
			formats: [BarcodeFormat] = [],
			tryHarder: Bool? = nil,
			tryRotate: Bool? = nil,
			tryInvert: Bool? = nil,
			tryDownscale: Bool? = nil,
			isPure: Bool? = nil,
			returnErrors: Bool? = nil,
			binarizer: Binarizer? = nil,
			textMode: TextMode? = nil,
			characterSet: CharacterSet? = nil,
			minLineCount: Int? = nil,
			maxNumberOfSymbols: Int? = nil,
			eanAddOnSymbol: EanAddOnSymbol? = nil,
			validateOptionalChecksum: Bool? = nil
		) {
			self.formats = formats
			self.tryHarder = tryHarder ?? Self.cDefaults.tryHarder
			self.tryRotate = tryRotate ?? Self.cDefaults.tryRotate
			self.tryInvert = tryInvert ?? Self.cDefaults.tryInvert
			self.tryDownscale = tryDownscale ?? Self.cDefaults.tryDownscale
			self.isPure = isPure ?? Self.cDefaults.isPure
			self.returnErrors = returnErrors ?? Self.cDefaults.returnErrors
			self.binarizer = binarizer ?? Self.cDefaults.binarizer
			self.textMode = textMode ?? Self.cDefaults.textMode
			self.characterSet = characterSet ?? Self.cDefaults.characterSet
			self.minLineCount = minLineCount ?? Self.cDefaults.minLineCount
			self.maxNumberOfSymbols = maxNumberOfSymbols ?? Self.cDefaults.maxNumberOfSymbols
			self.eanAddOnSymbol = eanAddOnSymbol ?? Self.cDefaults.eanAddOnSymbol
			self.validateOptionalChecksum = validateOptionalChecksum ?? Self.cDefaults.validateOptionalChecksum
		}

		fileprivate var normalizedFormats: [BarcodeFormat] {
			Array(Set(formats)).sorted { $0.rawValue < $1.rawValue }
		}

		public static func == (lhs: Self, rhs: Self) -> Bool {
			lhs.normalizedFormats == rhs.normalizedFormats &&
			lhs.tryHarder == rhs.tryHarder &&
			lhs.tryRotate == rhs.tryRotate &&
			lhs.tryInvert == rhs.tryInvert &&
			lhs.tryDownscale == rhs.tryDownscale &&
			lhs.isPure == rhs.isPure &&
			lhs.returnErrors == rhs.returnErrors &&
			lhs.binarizer == rhs.binarizer &&
			lhs.textMode == rhs.textMode &&
			lhs.characterSet == rhs.characterSet &&
			lhs.minLineCount == rhs.minLineCount &&
			lhs.maxNumberOfSymbols == rhs.maxNumberOfSymbols &&
			lhs.eanAddOnSymbol == rhs.eanAddOnSymbol &&
			lhs.validateOptionalChecksum == rhs.validateOptionalChecksum
		}

		public func hash(into hasher: inout Hasher) {
			hasher.combine(normalizedFormats)
			hasher.combine(tryHarder)
			hasher.combine(tryRotate)
			hasher.combine(tryInvert)
			hasher.combine(tryDownscale)
			hasher.combine(isPure)
			hasher.combine(returnErrors)
			hasher.combine(binarizer)
			hasher.combine(textMode)
			hasher.combine(characterSet)
			hasher.combine(minLineCount)
			hasher.combine(maxNumberOfSymbols)
			hasher.combine(eanAddOnSymbol)
			hasher.combine(validateOptionalChecksum)
		}
	}

	public var configuration: Configuration

	public init(configuration: Configuration = .init()) {
		self.configuration = configuration
	}

	/// Reads barcodes from an image view using this reader configuration.
	///
	/// This method performs CPU-intensive image processing synchronously on the calling thread.
	/// Avoid calling from the main thread in UI applications. Because `ImageView` is not `Sendable`,
	/// create and use it within the same task or queue that performs decoding; prefer passing `Data`,
	/// `CGImage`, or other owned image sources into background work rather than sharing an `ImageView`
	/// across concurrency domains.
	public func read(from image: ImageView) throws -> [Barcode] {
		try withCReaderOptions(configuration) { optionsHandle in
			guard let barcodes = ZXing_ReadBarcodes(image._handle, optionsHandle) else { throw lastError() }
			defer { ZXing_Barcodes_delete(barcodes) }

			let size = ZXing_Barcodes_size(barcodes)
			guard size > 0 else { return [] }

			var result: [Barcode] = []
			result.reserveCapacity(Int(size))
			for i in 0..<Int32(size) {
				guard let handle = ZXing_Barcodes_move(barcodes, i) else {
					throw ZXingError("Failed to move barcode at index \(i)")
				}
				result.append(try Barcode(handle))
			}
			return result
		}
	}

	public var debugDescription: String {
		"BarcodeReader(formats: \(configuration.normalizedFormats.map { $0.description }), tryHarder: \(configuration.tryHarder))"
	}
}

private func withCReaderOptions<T>(_ configuration: BarcodeReader.Configuration, _ body: (OpaquePointer) throws -> T) throws -> T {
	guard let handle = ZXing_ReaderOptions_new() else { throw lastError() }
	defer { ZXing_ReaderOptions_delete(handle) }

	let formats = configuration.normalizedFormats
	if !formats.isEmpty {
		try formats.withCFormats { ptr, count in
			ZXing_ReaderOptions_setFormats(handle, ptr, count)
		}
	}
	ZXing_ReaderOptions_setTryHarder(handle, configuration.tryHarder)
	ZXing_ReaderOptions_setTryRotate(handle, configuration.tryRotate)
	ZXing_ReaderOptions_setTryInvert(handle, configuration.tryInvert)
	ZXing_ReaderOptions_setTryDownscale(handle, configuration.tryDownscale)
	ZXing_ReaderOptions_setIsPure(handle, configuration.isPure)
	ZXing_ReaderOptions_setReturnErrors(handle, configuration.returnErrors)
	ZXing_ReaderOptions_setBinarizer(handle, try checkedCEnum(configuration.binarizer.rawValue))
	ZXing_ReaderOptions_setTextMode(handle, try checkedCEnum(configuration.textMode.rawValue))
	ZXing_ReaderOptions_setCharacterSet(handle, try checkedCEnum(configuration.characterSet.rawValue))
	ZXing_ReaderOptions_setMinLineCount(handle, try checkedUInt8BackedInt(configuration.minLineCount, name: "BarcodeReader.Configuration.minLineCount"))
	ZXing_ReaderOptions_setMaxNumberOfSymbols(handle, try checkedUInt8BackedInt(configuration.maxNumberOfSymbols, name: "BarcodeReader.Configuration.maxNumberOfSymbols"))
	ZXing_ReaderOptions_setEanAddOnSymbol(handle, try checkedCEnum(configuration.eanAddOnSymbol.rawValue))
	ZXing_ReaderOptions_setValidateOptionalChecksum(handle, configuration.validateOptionalChecksum)

	return try body(handle)
}
