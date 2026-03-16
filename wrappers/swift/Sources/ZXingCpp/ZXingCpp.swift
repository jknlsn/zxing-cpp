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
	guard let ptr, len > 0 else { return Data() }
	let data = Data(bytes: ptr, count: Int(len))
	ZXing_free(ptr)
	return data
}

private func lastError() -> ZXingError {
	if let msg = ZXing_LastErrorMsg() {
		return ZXingError(c2s(msg))
	}
	return ZXingError("Unknown ZXing error")
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

	public var description: String {
		guard let cValue: ZXing_BarcodeFormat = cEnum(rawValue) else { return "Unknown(\(rawValue))" }
		return c2s(ZXing_BarcodeFormatToString(cValue))
	}

	/// The base symbology for this format (e.g., `.ean13` returns `.eanUPC`).
	public var symbology: BarcodeFormat {
		guard let cValue: ZXing_BarcodeFormat = cEnum(rawValue) else { return self }
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
	public static let allGS1            = BarcodeFormat(rawValue: 0x672A)

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

public typealias BarcodeFormats = [BarcodeFormat]

extension Array where Element == BarcodeFormat {
	/// Returns individual formats matching the given filter.
	public static func list(_ filter: BarcodeFormat = .all) -> Self {
		var count: Int32 = 0
		guard let cFilter: ZXing_BarcodeFormat = cEnum(filter.rawValue) else { return [] }
		guard let ptr = ZXing_BarcodeFormatsList(cFilter, &count), count > 0 else { return [] }
		let formats = (0..<Int(count)).map { BarcodeFormat(rawValue: sEnum(ptr[$0])) }
		ZXing_free(ptr)
		return formats
	}

	/// Parses a comma-separated string of format names into an array of `BarcodeFormat`. Returns `nil` on failure.
	public init?(string: String) {
		var count: Int32 = 0
		let ptr = string.withCString { ZXing_BarcodeFormatsFromString($0, &count) }
		if ptr != nil && count > 0 {
			self = (0..<Int(count)).map { BarcodeFormat(rawValue: sEnum(ptr![$0])) }
			ZXing_free(ptr)
		} else if let msg = ZXing_LastErrorMsg() {
			ZXing_free(msg)
			return nil
		} else {
			self = []
		}
	}
}

private func checkedBarcodeFormat(_ format: BarcodeFormat) throws -> ZXing_BarcodeFormat {
	guard let cFormat: ZXing_BarcodeFormat = cEnum(format.rawValue) else {
		throw unknownCEnumError(format.rawValue, type: BarcodeFormat.self)
	}
	return cFormat
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
}

public enum ContentType: Int32, Sendable, CustomStringConvertible {
	case text       = 0
	case binary     = 1
	case mixed      = 2
	case gs1        = 3
	case iso15434   = 4
	case unknownECI = 5

	public var description: String {
		guard let cValue: ZXing_ContentType = cEnum(rawValue) else { return "unknown" }
		return c2s(ZXing_ContentTypeToString(cValue))
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

// MARK: - Point & Position

public struct Point: Hashable, Sendable, CustomStringConvertible {
	public var x: Int
	public var y: Int

	public var description: String { "\(x)x\(y)" }

	public init(x: Int, y: Int) { self.x = x; self.y = y }

	init(_ p: ZXing_PointI) { x = Int(p.x); y = Int(p.y) }
}

public struct Position: Sendable, CustomStringConvertible {
	public var topLeft: Point
	public var topRight: Point
	public var bottomRight: Point
	public var bottomLeft: Point

	public var description: String {
		c2s(ZXing_PositionToString(cPosition))
	}

	init(_ p: ZXing_Position) {
		topLeft = Point(p.topLeft)
		topRight = Point(p.topRight)
		bottomRight = Point(p.bottomRight)
		bottomLeft = Point(p.bottomLeft)
	}

	private var cPosition: ZXing_Position {
		ZXing_Position(
			topLeft: ZXing_PointI(x: Int32(topLeft.x), y: Int32(topLeft.y)),
			topRight: ZXing_PointI(x: Int32(topRight.x), y: Int32(topRight.y)),
			bottomRight: ZXing_PointI(x: Int32(bottomRight.x), y: Int32(bottomRight.y)),
			bottomLeft: ZXing_PointI(x: Int32(bottomLeft.x), y: Int32(bottomLeft.y))
		)
	}
}

// MARK: - ImageView

/// A non-owning view into image pixel data for barcode detection.
public class ImageView {
	internal let _handle: OpaquePointer
	private let _retainedSource: AnyObject?

	private static func makeHandle(
		pointer: UnsafePointer<UInt8>?, size: Int, width: Int, height: Int, format: ImageFormat, rowStride: Int, pixStride: Int
	) throws -> OpaquePointer {
		let cFormat: ZXing_ImageFormat = try checkedCEnum(format.rawValue)
		guard let iv = ZXing_ImageView_new_checked(
			pointer, Int32(size), Int32(width), Int32(height), cFormat, Int32(rowStride), Int32(pixStride)
		) else {
			throw lastError()
		}
		return iv
	}

	/// Creates an ImageView from Data without additional pixel buffer copying.
	public init( data: Data, width: Int, height: Int, format: ImageFormat, rowStride: Int = 0, pixStride: Int = 0) throws {
		let nsData = data as NSData
		let pointer: UnsafePointer<UInt8>? = nsData.length > 0
			? nsData.bytes.bindMemory(to: UInt8.self, capacity: nsData.length)
			: nil
		_handle = try Self.makeHandle(pointer: pointer, size: nsData.length,
			width: width, height: height, format: format, rowStride: rowStride, pixStride: pixStride)
		_retainedSource = nsData
	}

	/// Creates an ImageView from an external data source. The source is retained to keep the pointer valid.
	public init(
		pointer: UnsafePointer<UInt8>, size: Int, width: Int, height: Int, format: ImageFormat,
		rowStride: Int = 0, pixStride: Int = 0, retaining source: AnyObject
	) throws {
		_handle = try Self.makeHandle(
			pointer: pointer, size: size, width: width, height: height, format: format, rowStride: rowStride, pixStride: pixStride)
		_retainedSource = source
	}

	deinit {
		ZXing_ImageView_delete(_handle)
	}

	/// Crops the image view to the given rectangle.
	public func crop(left: Int, top: Int, width: Int, height: Int) {
		ZXing_ImageView_crop(_handle, Int32(left), Int32(top), Int32(width), Int32(height))
	}

	/// Rotates the image view by the given degrees (must be a multiple of 90).
	public func rotate(by degrees: Int) {
		ZXing_ImageView_rotate(_handle, Int32(degrees))
	}
}

// MARK: - Image

/// An owned image returned by barcode writing operations.
public class Image {
	internal let _handle: OpaquePointer

	internal init(_ handle: OpaquePointer) { _handle = handle }

	deinit { ZXing_Image_delete(_handle) }

	public var width: Int { Int(ZXing_Image_width(_handle)) }
	public var height: Int { Int(ZXing_Image_height(_handle)) }
	public var format: ImageFormat { ImageFormat(rawValue: sEnum(ZXing_Image_format(_handle))) ?? .none }

	/// The raw pixel data as a copy.
	public var data: Data {
		guard let ptr = ZXing_Image_data(_handle) else { return Data() }
		return Data(bytes: ptr, count: width * height)
	}
}

// MARK: - WriterOptions

/// Options for rendering barcodes to images or SVG.
public struct WriterOptions: Sendable, Hashable {
	/// Scaling factor (>0: pixels per module, <0: target size in pixels).
	public var scale: Int

	/// Rotation in degrees (0, 90, 180, or 270).
	public var rotate: Int

	/// Add human-readable text below linear barcodes.
	public var addHRT: Bool

	/// Add quiet zones (white margins) around the barcode.
	public var addQuietZones: Bool

	private static let cDefaults: (scale: Int, rotate: Int, addHRT: Bool, addQuietZones: Bool) = {
		let handle = ZXing_WriterOptions_new()!
		defer { ZXing_WriterOptions_delete(handle) }
		return (
			scale: Int(ZXing_WriterOptions_getScale(handle)),
			rotate: Int(ZXing_WriterOptions_getRotate(handle)),
			addHRT: ZXing_WriterOptions_getAddHRT(handle),
			addQuietZones: ZXing_WriterOptions_getAddQuietZones(handle)
		)
	}()

	public init(scale: Int? = nil, rotate: Int? = nil, addHRT: Bool? = nil, addQuietZones: Bool? = nil) {
		self.scale = scale ?? Self.cDefaults.scale
		self.rotate = rotate ?? Self.cDefaults.rotate
		self.addHRT = addHRT ?? Self.cDefaults.addHRT
		self.addQuietZones = addQuietZones ?? Self.cDefaults.addQuietZones
	}
}

private func withCWriterOptions<T>(_ options: WriterOptions, _ body: (OpaquePointer) throws -> T) throws -> T {
	guard let handle = ZXing_WriterOptions_new() else { throw lastError() }
	defer { ZXing_WriterOptions_delete(handle) }

	ZXing_WriterOptions_setScale(handle, Int32(options.scale))
	ZXing_WriterOptions_setRotate(handle, Int32(options.rotate))
	ZXing_WriterOptions_setAddHRT(handle, options.addHRT)
	ZXing_WriterOptions_setAddQuietZones(handle, options.addQuietZones)

	return try body(handle)
}

// MARK: - Barcode

/// Retains the native barcode handle for operations that cannot be eagerly copied.
/// Access is serialized so `Barcode` can safely remain `Sendable` at the Swift layer.
private final class NativeBarcodeStorage: @unchecked Sendable {
	private let handle: OpaquePointer
	private let lock = NSLock()
	var handleIdentity: UInt { UInt(bitPattern: handle) }

	init(_ handle: OpaquePointer) { self.handle = handle }

	deinit { ZXing_Barcode_delete(handle) }

	func extra(key: String) -> String {
		lock.lock()
		defer { lock.unlock() }
		return key.withCString { c2s(ZXing_Barcode_extra(handle, $0)) }
	}

	func toSVG(_ options: WriterOptions?) throws -> String {
		lock.lock()
		defer { lock.unlock() }
		return try withCWriterOptions(options ?? .init()) { optionsHandle in
			guard let ptr = ZXing_WriteBarcodeToSVG(handle, optionsHandle) else { throw lastError() }
			return c2s(ptr)
		}
	}

	func toImage(_ options: WriterOptions?) throws -> Image {
		lock.lock()
		defer { lock.unlock() }
		return try withCWriterOptions(options ?? .init()) { optionsHandle in
			guard let ptr = ZXing_WriteBarcodeToImage(handle, optionsHandle) else { throw lastError() }
			return Image(ptr)
		}
	}
}

/// A detected or created barcode.
public struct Barcode: Sendable, Equatable, Hashable {
	private let storage: NativeBarcodeStorage
	private let extraJSON: String

	internal init(_ handle: OpaquePointer) throws {
		storage = NativeBarcodeStorage(handle)
		isValid = ZXing_Barcode_isValid(handle)
		format = BarcodeFormat(rawValue: sEnum(ZXing_Barcode_format(handle)))
		symbology = BarcodeFormat(rawValue: sEnum(ZXing_Barcode_symbology(handle)))
		contentType = try checkedSwiftEnum(sEnum(ZXing_Barcode_contentType(handle)))
		text = c2s(ZXing_Barcode_text(handle))
		var len: Int32 = 0
		bytes = c2bytes(ZXing_Barcode_bytes(handle, &len), len)
		var eciLen: Int32 = 0
		bytesECI = c2bytes(ZXing_Barcode_bytesECI(handle, &eciLen), eciLen)
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
		extraJSON = c2s(ZXing_Barcode_extra(handle, nil))
	}

	/// Creates a barcode from text content.
	public init(_ text: String, format: BarcodeFormat, options: String? = nil) throws {
		guard let opts = ZXing_CreatorOptions_new(try checkedBarcodeFormat(format)) else { throw lastError() }
		defer { ZXing_CreatorOptions_delete(opts) }
		if let options {
			options.withCString { ZXing_CreatorOptions_setOptions(opts, $0) }
		}
		guard let bc = ZXing_CreateBarcodeFromText(text, 0, opts) else { throw lastError() }
		self = try Barcode(bc)
	}

	/// Creates a barcode from binary data.
	public init(bytes: Data, format: BarcodeFormat, options: String? = nil) throws {
		guard let opts = ZXing_CreatorOptions_new(try checkedBarcodeFormat(format)) else { throw lastError() }
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

	/// ISO/IEC 15424 symbology identifier (e.g., "]Q1" for QR Code).
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

	/// Additional format-specific metadata as JSON.
	/// - Parameter key: Optional key to retrieve a specific value. Pass `nil` for the full JSON object.
	public func extra(key: String? = nil) -> String {
		guard let key else { return extraJSON }
		return storage.extra(key: key)
	}

	/// Renders the barcode as an SVG string.
	public func toSVG(_ options: WriterOptions? = nil) throws -> String {
		try storage.toSVG(options)
	}

	/// Renders the barcode as a grayscale image.
	public func toImage(_ options: WriterOptions? = nil) throws -> Image {
		try storage.toImage(options)
	}

	public static func == (lhs: Barcode, rhs: Barcode) -> Bool {
		lhs.storage.handleIdentity == rhs.storage.handleIdentity
	}

	public func hash(into hasher: inout Hasher) {
		hasher.combine(storage.handleIdentity)
	}
}

// MARK: - BarcodeReader

/// Barcode reader with configurable detection options.
///
/// Usage:
/// ```swift
/// let reader = BarcodeReader(formats: [.qrCode, .ean13], returnErrors: true)
/// let barcodes = try reader.read(from: imageView)
/// ```
public struct BarcodeReader: Sendable {
	public var formats: [BarcodeFormat]
	public var tryHarder: Bool
	public var tryRotate: Bool
	public var tryInvert: Bool
	public var tryDownscale: Bool
	public var isPure: Bool
	public var returnErrors: Bool
	public var binarizer: Binarizer
	public var textMode: TextMode
	public var minLineCount: Int
	public var maxNumberOfSymbols: Int
	public var eanAddOnSymbol: EanAddOnSymbol
	public var validateOptionalChecksum: Bool

	private static let cDefaults: (
		tryHarder: Bool,
		tryRotate: Bool,
		tryInvert: Bool,
		tryDownscale: Bool,
		isPure: Bool,
		returnErrors: Bool,
		binarizer: Binarizer,
		textMode: TextMode,
		minLineCount: Int,
		maxNumberOfSymbols: Int,
		eanAddOnSymbol: EanAddOnSymbol,
		validateOptionalChecksum: Bool
	) = {
		let handle = ZXing_ReaderOptions_new()!
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
			minLineCount: Int(ZXing_ReaderOptions_getMinLineCount(handle)),
			maxNumberOfSymbols: Int(ZXing_ReaderOptions_getMaxNumberOfSymbols(handle)),
			eanAddOnSymbol: swiftEnum(sEnum(ZXing_ReaderOptions_getEanAddOnSymbol(handle))) ?? .ignore,
			validateOptionalChecksum: ZXing_ReaderOptions_getValidateOptionalChecksum(handle)
		)
	}()

	public init(
		formats: [BarcodeFormat]? = nil,
		tryHarder: Bool? = nil,
		tryRotate: Bool? = nil,
		tryInvert: Bool? = nil,
		tryDownscale: Bool? = nil,
		isPure: Bool? = nil,
		returnErrors: Bool? = nil,
		binarizer: Binarizer? = nil,
		textMode: TextMode? = nil,
		minLineCount: Int? = nil,
		maxNumberOfSymbols: Int? = nil,
		eanAddOnSymbol: EanAddOnSymbol? = nil,
		validateOptionalChecksum: Bool? = nil
	) {
		self.formats = formats ?? []
		self.tryHarder = tryHarder ?? Self.cDefaults.tryHarder
		self.tryRotate = tryRotate ?? Self.cDefaults.tryRotate
		self.tryInvert = tryInvert ?? Self.cDefaults.tryInvert
		self.tryDownscale = tryDownscale ?? Self.cDefaults.tryDownscale
		self.isPure = isPure ?? Self.cDefaults.isPure
		self.returnErrors = returnErrors ?? Self.cDefaults.returnErrors
		self.binarizer = binarizer ?? Self.cDefaults.binarizer
		self.textMode = textMode ?? Self.cDefaults.textMode
		self.minLineCount = minLineCount ?? Self.cDefaults.minLineCount
		self.maxNumberOfSymbols = maxNumberOfSymbols ?? Self.cDefaults.maxNumberOfSymbols
		self.eanAddOnSymbol = eanAddOnSymbol ?? Self.cDefaults.eanAddOnSymbol
		self.validateOptionalChecksum = validateOptionalChecksum ?? Self.cDefaults.validateOptionalChecksum
	}

	/// Reads barcodes from an image view using this reader's options.
	public func read(from image: ImageView) throws -> [Barcode] {
		try withCReaderOptions(self) { optionsHandle in
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
}

private func withCReaderOptions<T>(_ options: BarcodeReader, _ body: (OpaquePointer) throws -> T) throws -> T {
	guard let handle = ZXing_ReaderOptions_new() else { throw lastError() }
	defer { ZXing_ReaderOptions_delete(handle) }

	if !options.formats.isEmpty {
		try options.formats.withCFormats { ptr, count in
			ZXing_ReaderOptions_setFormats(handle, ptr, count)
		}
	}
	ZXing_ReaderOptions_setTryHarder(handle, options.tryHarder)
	ZXing_ReaderOptions_setTryRotate(handle, options.tryRotate)
	ZXing_ReaderOptions_setTryInvert(handle, options.tryInvert)
	ZXing_ReaderOptions_setTryDownscale(handle, options.tryDownscale)
	ZXing_ReaderOptions_setIsPure(handle, options.isPure)
	ZXing_ReaderOptions_setReturnErrors(handle, options.returnErrors)
	ZXing_ReaderOptions_setBinarizer(handle, try checkedCEnum(options.binarizer.rawValue))
	ZXing_ReaderOptions_setTextMode(handle, try checkedCEnum(options.textMode.rawValue))
	ZXing_ReaderOptions_setMinLineCount(handle, Int32(options.minLineCount))
	ZXing_ReaderOptions_setMaxNumberOfSymbols(handle, Int32(options.maxNumberOfSymbols))
	ZXing_ReaderOptions_setEanAddOnSymbol(handle, try checkedCEnum(options.eanAddOnSymbol.rawValue))
	ZXing_ReaderOptions_setValidateOptionalChecksum(handle, options.validateOptionalChecksum)

	return try body(handle)
}
