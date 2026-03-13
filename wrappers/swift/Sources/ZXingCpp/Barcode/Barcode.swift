// Copyright 2026 Axel Waggershauser
// SPDX-License-Identifier: Apache-2.0

import Foundation
import ZXingCBridge

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
			ZXing_CreateBarcodeFromText(buffer.baseAddress, size, opts)
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
