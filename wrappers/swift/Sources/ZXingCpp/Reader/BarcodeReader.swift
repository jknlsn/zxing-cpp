// Copyright 2026 Axel Waggershauser
// SPDX-License-Identifier: Apache-2.0

import Foundation
import ZXingCBridge

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
			tryHarder: Bool,
			tryRotate: Bool,
			tryInvert: Bool,
			tryDownscale: Bool,
			isPure: Bool,
			returnErrors: Bool,
			binarizer: Binarizer,
			textMode: TextMode,
			characterSet: CharacterSet,
			minLineCount: Int,
			maxNumberOfSymbols: Int,
			eanAddOnSymbol: EanAddOnSymbol,
			validateOptionalChecksum: Bool
		) = {
			guard let handle = ZXing_ReaderOptions_new() else {
				// Allocation failure at static init is unrecoverable; fall back to known C++ defaults.
				return (
					tryHarder: true,
					tryRotate: true,
					tryInvert: true,
					tryDownscale: true,
					isPure: false,
					returnErrors: false,
					binarizer: .localAverage,
					textMode: .hri,
					characterSet: .unknown,
					minLineCount: 2,
					maxNumberOfSymbols: 255,
					eanAddOnSymbol: .ignore,
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

func withCReaderOptions<T>(_ configuration: BarcodeReader.Configuration, _ body: (OpaquePointer) throws -> T) throws -> T {
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
