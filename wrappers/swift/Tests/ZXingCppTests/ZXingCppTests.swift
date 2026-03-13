import XCTest
@testable import ZXingCpp
import ZXingCBridge

#if canImport(CoreImage)
import CoreImage
import CoreImage.CIFilterBuiltins
#endif

#if canImport(UIKit)
import UIKit
#endif

final class ZXingCppTests: XCTestCase {
	func testBarcodeIsValueSemanticAndSendable() throws {
		let first = try Barcode("Hello World", format: .qrCode)
		let second = try Barcode("Hello World", format: .qrCode)

		requireSendable(first)
		XCTAssertEqual(first, second)
		XCTAssertEqual(Set([first, second]).count, 1)
		XCTAssertFalse(try first.toSVG().isEmpty)
	}

	func testDetectedBarcodesCompareByValue() throws {
		let created = try Barcode("Value Semantics", format: .qrCode)
		let image = try created.toImage()
		let imageView = try ImageView(data: image.data, width: image.width, height: image.height, format: image.format)
		let reader = BarcodeReader(configuration: .init(formats: [.qrCode], tryDownscale: false, isPure: true))

		let first = try XCTUnwrap(try reader.read(from: imageView).first)
		let second = try XCTUnwrap(try reader.read(from: imageView).first)

		XCTAssertEqual(first, second)
		XCTAssertEqual(Set([first, second]).count, 1)
		XCTAssertEqual(Set([first.position, second.position]).count, 1)
	}

	func testTypedBarcodeCreationOptions() throws {
		let barcode = try Barcode(
			"Typed Options",
			options: .qrCode(
				QRCodeOptions(
					errorCorrection: .high,
					eci: .utf8,
					version: 7,
					dataMask: .pattern3
				)
			)
		)

		XCTAssertEqual(barcode.format, .qrCode)
		XCTAssertFalse(try barcode.toSVG().isEmpty)
	}

	func testTypedBarcodeCreationRejectsNegativeECIValue() {
		XCTAssertThrowsError(
			try Barcode(
				"Typed Options",
				options: .qrCode(
					QRCodeOptions(eci: .value(-1))
				)
			)
		) { error in
			guard let zxingError = error as? ZXingError else {
				XCTFail("Expected ZXingError, got \(type(of: error))")
				return
			}
			XCTAssertEqual(zxingError.description, "ECI.value must be non-negative")
		}
	}

	func testBarcodeFormatFilterConstantsMatchExpectedEnabledFormats() {
		XCTAssertEqual(
			Set(BarcodeFormat.all(matching: .allGS1)),
			expectedEnabledFormats([
				.code128,
				.dataBar,
				.dataBarOmni,
				.dataBarStk,
				.dataBarStkOmni,
				.dataBarLtd,
				.dataBarExp,
				.dataBarExpStk,
				.aztec,
				.aztecCode,
				.qrCode,
				.rmqrCode,
				.dataMatrix,
			])
		)

		XCTAssertEqual(
			Set(BarcodeFormat.all(matching: .allRetail)),
			expectedEnabledFormats([
				.dataBar,
				.dataBarOmni,
				.dataBarStk,
				.dataBarStkOmni,
				.dataBarLtd,
				.dataBarExp,
				.dataBarExpStk,
				.eanUPC,
				.ean13,
				.ean8,
				.ean5,
				.ean2,
				.isbn,
				.upcA,
				.upcE,
			])
		)

		XCTAssertEqual(
			Set(BarcodeFormat.all(matching: .allIndustrial)),
			expectedEnabledFormats([
				.code39,
				.code39Std,
				.code39Ext,
				.code32,
				.pzn,
				.code93,
				.code128,
				.itf,
				.itf14,
			])
		)
	}

	func testQRCodeRoundTripPreservesExposedMetadata() throws {
		let created = try Barcode(
			"Hello QR",
			options: .qrCode(
				QRCodeOptions(
					errorCorrection: .high,
					version: 7,
					dataMask: .pattern3
				)
			)
		)

		let decoded = try roundTrip(created, formats: [.qrCode])

		XCTAssertEqual(decoded.text, "Hello QR")
		XCTAssertEqual(decoded.bytes, Data("Hello QR".utf8))
		XCTAssertEqual(decoded.format, .qrCode)
		XCTAssertEqual(decoded.metadata(forKey: "ECLevel"), "H")
		XCTAssertEqual(decoded.metadata(forKey: "Version"), "7")
		XCTAssertEqual(decoded.metadata(forKey: "DataMask"), "3")
	}

	func testDataMatrixRoundTripPreservesVersionMetadata() throws {
		let created = try Barcode(
			"Hello DM",
			options: .dataMatrix(
				DataMatrixOptions(forceSquare: true)
			)
		)

		let decoded = try roundTrip(created, formats: [.dataMatrix])

		XCTAssertEqual(decoded.text, "Hello DM")
		XCTAssertEqual(decoded.bytes, Data("Hello DM".utf8))
		XCTAssertEqual(decoded.format, .dataMatrix)
		XCTAssertFalse(decoded.metadata(forKey: "Version").isEmpty)
	}

	func testPDF417TypedCreationOptions() throws {
		let barcode = try Barcode(
			"PDF417",
			options: .pdf417(
				PDF417Options(
					errorCorrectionLevel: .level4,
					columns: 4,
					rows: 12
				)
			)
		)

		XCTAssertEqual(barcode.format, .pdf417)
		XCTAssertFalse(try barcode.toSVG().isEmpty)
	}

	func testPDF417RoundTripPreservesExposedMetadata() throws {
		let created = try Barcode(
			"Hello PDF",
			options: .pdf417(
				PDF417Options(
					errorCorrectionLevel: .level4,
					columns: 4,
					rows: 12
				)
			)
		)

		let decoded = try roundTrip(created, formats: [.pdf417])

		XCTAssertEqual(decoded.text, "Hello PDF")
		XCTAssertEqual(decoded.bytes, Data("Hello PDF".utf8))
		XCTAssertEqual(decoded.format, .pdf417)
		XCTAssertFalse(decoded.metadata(forKey: "ECLevel").isEmpty)
	}

	func testAztecRoundTripPreservesExposedMetadata() throws {
		let created = try Barcode(
			"Hello Aztec",
			options: .aztec(
				AztecOptions(errorCorrectionPercent: 23)
			)
		)

		let decoded = try roundTrip(created, formats: [.aztec])

		XCTAssertEqual(decoded.text, "Hello Aztec")
		XCTAssertEqual(decoded.bytes, Data("Hello Aztec".utf8))
		XCTAssertEqual(decoded.format, .aztec)
		XCTAssertFalse(decoded.metadata(forKey: "Version").isEmpty)
		XCTAssertFalse(decoded.metadata(forKey: "ECLevel").isEmpty)
	}

	func testTextCreationPreservesEmbeddedNullInBytes() throws {
		let barcode = try Barcode("A\0B", format: .qrCode)
		XCTAssertEqual(barcode.bytes, Data([0x41, 0x00, 0x42]))
	}

	func testBinaryRoundTripPreservesDecodedBytes() throws {
		let payload = Data([0x00, 0x01, 0xFF, 0x41, 0x00])
		let created = try Barcode(
			bytes: payload,
			options: .qrCode(
				QRCodeOptions(eci: .binary)
			)
		)

		let decoded = try roundTrip(created, formats: [.qrCode])

		XCTAssertEqual(decoded.bytes, payload)
		XCTAssertEqual(decoded.format, .qrCode)
	}

	func testReaderConfigurationRejectsOutOfRangeCounts() throws {
		let imageView = try ImageView(data: Data([0]), width: 1, height: 1, format: .lum)
		let reader = BarcodeReader(configuration: .init(maxNumberOfSymbols: 300))

		do {
			_ = try reader.read(from: imageView)
			XCTFail("Expected range validation to throw")
		} catch let error as ZXingError {
			XCTAssertTrue(error.description.contains("maxNumberOfSymbols"))
		}
	}

	func testReaderConfigurationRejectsOutOfRangeMinLineCount() throws {
		let imageView = try ImageView(data: Data([0]), width: 1, height: 1, format: .lum)
		let negativeReader = BarcodeReader(configuration: .init(minLineCount: -1))
		let overflowingReader = BarcodeReader(configuration: .init(minLineCount: 256))

		do {
			_ = try negativeReader.read(from: imageView)
			XCTFail("Expected negative minLineCount to throw")
		} catch let error as ZXingError {
			XCTAssertTrue(error.description.contains("minLineCount"))
		}

		do {
			_ = try overflowingReader.read(from: imageView)
			XCTFail("Expected overflowing minLineCount to throw")
		} catch let error as ZXingError {
			XCTAssertTrue(error.description.contains("minLineCount"))
		}
	}

	func testReaderConfigurationAcceptsBoundaryCounts() throws {
		let imageView = try ImageView(data: Data([0]), width: 1, height: 1, format: .lum)
		let reader = BarcodeReader(configuration: .init(minLineCount: 0, maxNumberOfSymbols: 255))

		XCTAssertNoThrow(try reader.read(from: imageView))
	}

	func testReaderConfigurationFormatsUseSetSemanticsForEqualityAndHashing() {
		let first = BarcodeReader.Configuration(formats: [.qrCode, .ean13, .qrCode], tryRotate: false)
		let second = BarcodeReader.Configuration(formats: [.ean13, .qrCode], tryRotate: false)

		requireSendable(first)
		XCTAssertEqual(first, second)
		XCTAssertEqual(Set([first, second]).count, 1)
	}

	#if canImport(CoreImage)
	func testReaderConfigurationCharacterSetOverrideMatchesDirectCAPIContract() throws {
		let imageView = try ImageView(cgImage: rawByteQRCodeCGImage())
		let iso8859Configuration = BarcodeReader.Configuration(
			formats: [.qrCode],
			tryDownscale: false,
			isPure: true,
			characterSet: .iso8859_1
		)
		let utf8Configuration = BarcodeReader.Configuration(
			formats: [.qrCode],
			tryDownscale: false,
			isPure: true,
			characterSet: .utf8
		)

		let iso8859Wrapped = try XCTUnwrap(try BarcodeReader(configuration: iso8859Configuration).read(from: imageView).first)
		let utf8Wrapped = try XCTUnwrap(try BarcodeReader(configuration: utf8Configuration).read(from: imageView).first)
		let iso8859Direct = try XCTUnwrap(try directCDecode(from: imageView, configuration: iso8859Configuration).first)
		let utf8Direct = try XCTUnwrap(try directCDecode(from: imageView, configuration: utf8Configuration).first)

		XCTAssertEqual(iso8859Wrapped, iso8859Direct)
		XCTAssertEqual(utf8Wrapped, utf8Direct)
		XCTAssertFalse(iso8859Direct.hasECI)
		XCTAssertFalse(utf8Direct.hasECI)
		XCTAssertEqual(iso8859Direct.bytes, Data([0xE9]))
		XCTAssertEqual(utf8Direct.bytes, iso8859Direct.bytes)
		XCTAssertEqual(iso8859Direct.text, "é")
		XCTAssertNotEqual(utf8Direct.text, iso8859Direct.text)
	}
	#endif

	#if canImport(UIKit) && canImport(CoreImage)
	func testBarcodeReaderReadFromUIImageNormalizesOrientationAndCISources() throws {
		let cgImage = try rawByteQRCodeCGImage()
		let orientedImage = UIImage(cgImage: cgImage, scale: 1, orientation: .right)
		let ciBackedImage = UIImage(ciImage: CIImage(cgImage: cgImage))
		let reader = BarcodeReader(configuration: .init(formats: [.qrCode], tryDownscale: false, isPure: true, characterSet: .iso8859_1))

		let orientedDecoded = try XCTUnwrap(try reader.read(from: orientedImage).first)
		let ciDecoded = try XCTUnwrap(try reader.read(from: ciBackedImage).first)

		XCTAssertEqual(orientedDecoded.bytes, Data([0xE9]))
		XCTAssertEqual(ciDecoded.bytes, Data([0xE9]))
		XCTAssertEqual(orientedDecoded.text, "é")
		XCTAssertEqual(ciDecoded.text, "é")
	}
	#endif

	func testRawStringBarcodeCreationOptionsEscapeHatch() throws {
		let barcode = try Barcode(
			"Escape Hatch",
			options: .rawString(format: .qrCode, payload: #"{"EcLevel":"H"}"#)
		)

		XCTAssertEqual(barcode.format, .qrCode)
		XCTAssertFalse(try barcode.toSVG().isEmpty)
	}

	func testCreatorOptionsOmitExplicitFalsePresenceFlags() throws {
		let serialized = try CreatorOptions(gs1: false, readerInit: false, forceSquare: false).serializedOptions()

		XCTAssertNil(serialized)
	}

	func testCreatorOptionsSerializeTruePresenceFlags() throws {
		let serialized = try XCTUnwrap(CreatorOptions(gs1: true, readerInit: true).serializedOptions())
		let object = try creatorOptionsJSONObject(from: serialized)

		XCTAssertEqual(object["GS1"] as? Bool, true)
		XCTAssertEqual(object["ReaderInit"] as? Bool, true)
		XCTAssertNil(object["ForceSquare"])
	}

	func testCreatorOptionsOmitFalsePresenceFlagsWhenOtherKeysArePresent() throws {
		let serialized = try XCTUnwrap(CreatorOptions(ecLevel: "H", gs1: false, readerInit: false).serializedOptions())
		let object = try creatorOptionsJSONObject(from: serialized)

		XCTAssertEqual(object["EcLevel"] as? String, "H")
		XCTAssertNil(object["GS1"])
		XCTAssertNil(object["ReaderInit"])
	}

	func testTypedDataMatrixOptionsSerializeForceSquarePresenceFlags() throws {
		let explicitTrue = try XCTUnwrap(
			BarcodeCreationOptions.dataMatrix(DataMatrixOptions(forceSquare: true)).serializedOptions()
		)
		let trueObject = try creatorOptionsJSONObject(from: explicitTrue)

		XCTAssertEqual(trueObject["ForceSquare"] as? Bool, true)

		let explicitFalse = try XCTUnwrap(
			BarcodeCreationOptions.dataMatrix(DataMatrixOptions(forceSquare: false, version: 12)).serializedOptions()
		)
		let falseObject = try creatorOptionsJSONObject(from: explicitFalse)

		XCTAssertEqual(falseObject["Version"] as? Int, 12)
		XCTAssertNil(falseObject["ForceSquare"])
	}

	func testTypedQRCodeOptionsSerializeReaderInitPresenceFlags() throws {
		let explicitTrue = try XCTUnwrap(
			BarcodeCreationOptions.qrCode(QRCodeOptions(readerInit: true, version: 7)).serializedOptions()
		)
		let trueObject = try creatorOptionsJSONObject(from: explicitTrue)

		XCTAssertEqual(trueObject["Version"] as? Int, 7)
		XCTAssertEqual(trueObject["ReaderInit"] as? Bool, true)

		let explicitFalse = try XCTUnwrap(
			BarcodeCreationOptions.qrCode(QRCodeOptions(readerInit: false, version: 7)).serializedOptions()
		)
		let falseObject = try creatorOptionsJSONObject(from: explicitFalse)

		XCTAssertEqual(falseObject["Version"] as? Int, 7)
		XCTAssertNil(falseObject["ReaderInit"])
	}

	func testTypedQRCodeOptionsSerializeGS1PresenceFlags() throws {
		let explicitTrue = try XCTUnwrap(
			BarcodeCreationOptions.qrCode(QRCodeOptions(gs1: true, version: 7)).serializedOptions()
		)
		let trueObject = try creatorOptionsJSONObject(from: explicitTrue)

		XCTAssertEqual(trueObject["Version"] as? Int, 7)
		XCTAssertEqual(trueObject["GS1"] as? Bool, true)

		let explicitFalse = try XCTUnwrap(
			BarcodeCreationOptions.qrCode(QRCodeOptions(gs1: false, version: 7)).serializedOptions()
		)
		let falseObject = try creatorOptionsJSONObject(from: explicitFalse)

		XCTAssertEqual(falseObject["Version"] as? Int, 7)
		XCTAssertNil(falseObject["GS1"])
	}

	func testTypedCode128OptionsSerializeReaderInitPresenceFlags() throws {
		let explicitTrue = try XCTUnwrap(
			BarcodeCreationOptions.code128(Code128Options(eci: .utf8, readerInit: true)).serializedOptions()
		)
		let trueObject = try creatorOptionsJSONObject(from: explicitTrue)

		XCTAssertEqual(trueObject["ECI"] as? String, "UTF-8")
		XCTAssertEqual(trueObject["ReaderInit"] as? Bool, true)

		let explicitFalse = try XCTUnwrap(
			BarcodeCreationOptions.code128(Code128Options(eci: .utf8, readerInit: false)).serializedOptions()
		)
		let falseObject = try creatorOptionsJSONObject(from: explicitFalse)

		XCTAssertEqual(falseObject["ECI"] as? String, "UTF-8")
		XCTAssertNil(falseObject["ReaderInit"])
	}

	func testTypedAndRawQRCodeCreationOptionsProduceMatchingDecodedMetadata() throws {
		let typed = try Barcode(
			"Parity",
			options: .qrCode(
				QRCodeOptions(
					errorCorrection: .high,
					version: 7,
					dataMask: .pattern3
				)
			)
		)
		let raw = try Barcode(
			"Parity",
			format: .qrCode,
			options: CreatorOptions(ecLevel: "H", version: 7, dataMask: 3)
		)

		_ = try assertRenderedImageEquals(typed, raw)
		let typedDecoded = try roundTrip(typed, formats: [.qrCode])
		let rawDecoded = try roundTrip(raw, formats: [.qrCode])

		XCTAssertEqual(typedDecoded.text, rawDecoded.text)
		XCTAssertEqual(typedDecoded.bytes, rawDecoded.bytes)
		XCTAssertEqual(typedDecoded.metadata(forKey: "ECLevel"), rawDecoded.metadata(forKey: "ECLevel"))
		XCTAssertEqual(typedDecoded.metadata(forKey: "Version"), rawDecoded.metadata(forKey: "Version"))
		XCTAssertEqual(typedDecoded.metadata(forKey: "DataMask"), rawDecoded.metadata(forKey: "DataMask"))
		XCTAssertEqual(typedDecoded.metadata(forKey: "ECLevel"), "H")
		XCTAssertEqual(typedDecoded.metadata(forKey: "Version"), "7")
		XCTAssertEqual(typedDecoded.metadata(forKey: "DataMask"), "3")
	}

	func testTypedAndRawDataMatrixCreationOptionsProduceMatchingDecodedMetadata() throws {
		let payload = String(repeating: "A", count: 20)
		let typed = try Barcode(payload, options: .dataMatrix(DataMatrixOptions(forceSquare: true)))
		let raw = try Barcode(payload, format: .dataMatrix, options: CreatorOptions(forceSquare: true))

		let typedImage = try assertRenderedImageEquals(typed, raw)
		let typedDecoded = try roundTrip(typed, formats: [.dataMatrix])
		let rawDecoded = try roundTrip(raw, formats: [.dataMatrix])

		XCTAssertEqual(typedImage.width, typedImage.height)
		XCTAssertEqual(typedDecoded.text, rawDecoded.text)
		XCTAssertEqual(typedDecoded.bytes, rawDecoded.bytes)
		XCTAssertEqual(typedDecoded.metadata(forKey: "Version"), rawDecoded.metadata(forKey: "Version"))
	}

	func testTypedAndRawPDF417CreationOptionsProduceMatchingDecodedMetadata() throws {
		let payload = "PDF417"
		let compactTyped = try Barcode(
			payload,
			options: .pdf417(PDF417Options(errorCorrectionLevel: .level0, columns: 4, rows: 12))
		)
		let compactRaw = try Barcode(
			payload,
			format: .pdf417,
			options: CreatorOptions(ecLevel: "0", columns: 4, rows: 12)
		)
		let denseTyped = try Barcode(
			payload,
			options: .pdf417(PDF417Options(errorCorrectionLevel: .level4, columns: 4, rows: 12))
		)
		let denseRaw = try Barcode(
			payload,
			format: .pdf417,
			options: CreatorOptions(ecLevel: "4", columns: 4, rows: 12)
		)

		_ = try assertRenderedImageEquals(compactTyped, compactRaw)
		_ = try assertRenderedImageEquals(denseTyped, denseRaw)
		let compactTypedDecoded = try roundTrip(compactTyped, formats: [.pdf417])
		let compactRawDecoded = try roundTrip(compactRaw, formats: [.pdf417])
		let denseTypedDecoded = try roundTrip(denseTyped, formats: [.pdf417])
		let denseRawDecoded = try roundTrip(denseRaw, formats: [.pdf417])
		let compactECLevel = compactTypedDecoded.metadata(forKey: "ECLevel")
		let denseECLevel = denseTypedDecoded.metadata(forKey: "ECLevel")

		XCTAssertEqual(compactTypedDecoded.text, compactRawDecoded.text)
		XCTAssertEqual(compactTypedDecoded.bytes, compactRawDecoded.bytes)
		XCTAssertEqual(compactECLevel, compactRawDecoded.metadata(forKey: "ECLevel"))
		XCTAssertFalse(compactECLevel.isEmpty)
		XCTAssertEqual(denseTypedDecoded.text, denseRawDecoded.text)
		XCTAssertEqual(denseTypedDecoded.bytes, denseRawDecoded.bytes)
		XCTAssertEqual(denseECLevel, denseRawDecoded.metadata(forKey: "ECLevel"))
		XCTAssertFalse(denseECLevel.isEmpty)
		XCTAssertNotEqual(compactECLevel, denseECLevel)
	}

	func testTypedAndRawAztecCreationOptionsProduceMatchingDecodedMetadata() throws {
		let payload = "Aztec parity payload"
		let lightTyped = try Barcode(payload, options: .aztec(AztecOptions(errorCorrectionPercent: 23)))
		let lightRaw = try Barcode(payload, format: .aztec, options: CreatorOptions(ecLevel: "23%"))
		let strongTyped = try Barcode(payload, options: .aztec(AztecOptions(errorCorrectionPercent: 50)))
		let strongRaw = try Barcode(payload, format: .aztec, options: CreatorOptions(ecLevel: "50%"))

		_ = try assertRenderedImageEquals(lightTyped, lightRaw)
		_ = try assertRenderedImageEquals(strongTyped, strongRaw)
		let lightTypedDecoded = try roundTrip(lightTyped, formats: [.aztec])
		let lightRawDecoded = try roundTrip(lightRaw, formats: [.aztec])
		let strongTypedDecoded = try roundTrip(strongTyped, formats: [.aztec])
		let strongRawDecoded = try roundTrip(strongRaw, formats: [.aztec])
		let lightECLevel = lightTypedDecoded.metadata(forKey: "ECLevel")
		let strongECLevel = strongTypedDecoded.metadata(forKey: "ECLevel")

		XCTAssertEqual(lightTypedDecoded.text, lightRawDecoded.text)
		XCTAssertEqual(lightTypedDecoded.bytes, lightRawDecoded.bytes)
		XCTAssertEqual(lightECLevel, lightRawDecoded.metadata(forKey: "ECLevel"))
		XCTAssertEqual(lightTypedDecoded.metadata(forKey: "Version"), lightRawDecoded.metadata(forKey: "Version"))
		XCTAssertFalse(lightECLevel.isEmpty)
		XCTAssertEqual(strongTypedDecoded.text, strongRawDecoded.text)
		XCTAssertEqual(strongTypedDecoded.bytes, strongRawDecoded.bytes)
		XCTAssertEqual(strongECLevel, strongRawDecoded.metadata(forKey: "ECLevel"))
		XCTAssertEqual(strongTypedDecoded.metadata(forKey: "Version"), strongRawDecoded.metadata(forKey: "Version"))
		XCTAssertFalse(strongECLevel.isEmpty)
		XCTAssertNotEqual(lightECLevel, strongECLevel)
	}

	func testTypedAndRawMaxiCodeCreationOptionsProduceMatchingRenderedAndDecodedOutput() throws {
		let payload = "MAXICODE"
		let typed = try Barcode(payload, options: .maxiCode(MaxiCodeOptions(mode: .mode6)))
		let raw = try Barcode(payload, format: .maxiCode, options: CreatorOptions(ecLevel: "6"))

		_ = try assertRenderedImageEquals(typed, raw)
		let typedDecoded = try roundTrip(typed, formats: [.maxiCode])
		let rawDecoded = try roundTrip(raw, formats: [.maxiCode])

		XCTAssertEqual(typedDecoded, rawDecoded)
		XCTAssertEqual(typedDecoded.metadata(forKey: "ECLevel"), "6")
	}

	func testTypedAndRawCode128CreationOptionsProduceMatchingRenderedAndDecodedOutput() throws {
		let payload = "(01)12345678901231"
		let typed = try Barcode(payload, options: .code128(Code128Options(gs1: true)))
		let raw = try Barcode(payload, format: .code128, options: CreatorOptions(gs1: true))

		_ = try assertRenderedImageEquals(typed, raw)
		let typedDecoded = try roundTrip(typed, formats: [.code128])
		let rawDecoded = try roundTrip(raw, formats: [.code128])

		XCTAssertEqual(typedDecoded, rawDecoded)
		XCTAssertEqual(typedDecoded.contentType, .gs1)
		XCTAssertEqual(typedDecoded.symbologyIdentifier, "]C1")
	}

	func testUnknownBarcodeFormatRawValueFailsSafely() throws {
		let unknown = BarcodeFormat(rawValue: 0x1234)

		XCTAssertEqual(BarcodeFormat.all(matching: unknown), [])
		XCTAssertTrue(unknown.description.contains("Unknown BarcodeFormat"))
		XCTAssertEqual(unknown.symbology, unknown)

			do {
			_ = try Barcode("Unknown Format", format: unknown)
			XCTFail("Expected invalid raw barcode format to throw")
		} catch let error as ZXingError {
			XCTAssertTrue(error.description.contains("Unknown C enum value"))
		}
	}

	private func requireSendable<T: Sendable>(_ value: T) {
		_ = value
	}

	private func assertRenderedImageEquals(
		_ lhs: Barcode,
		_ rhs: Barcode,
		file: StaticString = #filePath,
		line: UInt = #line
	) throws -> Image {
		let lhsImage = try lhs.toImage()
		let rhsImage = try rhs.toImage()

		XCTAssertEqual(lhsImage.width, rhsImage.width, file: file, line: line)
		XCTAssertEqual(lhsImage.height, rhsImage.height, file: file, line: line)
		XCTAssertEqual(lhsImage.format, rhsImage.format, file: file, line: line)
		XCTAssertEqual(lhsImage.data, rhsImage.data, file: file, line: line)

		return lhsImage
	}

	private func roundTrip(_ barcode: Barcode, formats: [BarcodeFormat]) throws -> Barcode {
		let image = try barcode.toImage()
		let imageView = try ImageView(data: image.data, width: image.width, height: image.height, format: image.format)
		let reader = BarcodeReader(configuration: .init(formats: formats, tryDownscale: false, isPure: true, returnErrors: false))
		return try XCTUnwrap(try reader.read(from: imageView).first(where: \.isValid))
	}

	private func directCDecode(from imageView: ImageView, configuration: BarcodeReader.Configuration) throws -> [Barcode] {
		guard let options = ZXing_ReaderOptions_new() else { throw bridgeLastError() }
		defer { ZXing_ReaderOptions_delete(options) }

		let formats = Set(configuration.formats).sorted { $0.rawValue < $1.rawValue }
		if !formats.isEmpty {
			let rawFormats = formats.map { format -> ZXing_BarcodeFormat in
				ZXing_BarcodeFormat(rawValue: UInt32(bitPattern: format.rawValue))
			}
			rawFormats.withUnsafeBufferPointer { buffer in
				ZXing_ReaderOptions_setFormats(options, buffer.baseAddress, Int32(buffer.count))
			}
		}

		ZXing_ReaderOptions_setTryHarder(options, configuration.tryHarder)
		ZXing_ReaderOptions_setTryRotate(options, configuration.tryRotate)
		ZXing_ReaderOptions_setTryInvert(options, configuration.tryInvert)
		ZXing_ReaderOptions_setTryDownscale(options, configuration.tryDownscale)
		ZXing_ReaderOptions_setIsPure(options, configuration.isPure)
		ZXing_ReaderOptions_setReturnErrors(options, configuration.returnErrors)
		ZXing_ReaderOptions_setBinarizer(options, ZXing_Binarizer(rawValue: UInt32(bitPattern: configuration.binarizer.rawValue)))
		ZXing_ReaderOptions_setTextMode(options, ZXing_TextMode(rawValue: UInt32(bitPattern: configuration.textMode.rawValue)))
		ZXing_ReaderOptions_setCharacterSet(options, ZXing_CharacterSet(rawValue: UInt32(bitPattern: configuration.characterSet.rawValue)))
		ZXing_ReaderOptions_setMinLineCount(options, Int32(configuration.minLineCount))
		ZXing_ReaderOptions_setMaxNumberOfSymbols(options, Int32(configuration.maxNumberOfSymbols))
		ZXing_ReaderOptions_setEanAddOnSymbol(options, ZXing_EanAddOnSymbol(rawValue: UInt32(bitPattern: configuration.eanAddOnSymbol.rawValue)))
		ZXing_ReaderOptions_setValidateOptionalChecksum(options, configuration.validateOptionalChecksum)

		guard let barcodes = ZXing_ReadBarcodes(imageView._handle, options) else { throw bridgeLastError() }
		defer { ZXing_Barcodes_delete(barcodes) }

		let size = ZXing_Barcodes_size(barcodes)
		guard size > 0 else { return [] }

		var result: [Barcode] = []
		result.reserveCapacity(Int(size))
		for index in 0..<Int32(size) {
			guard let handle = ZXing_Barcodes_move(barcodes, index) else {
				throw ZXingError("Failed to move barcode at index \(index)")
			}
			result.append(try Barcode(handle))
		}
		return result
	}

	private func bridgeLastError() -> ZXingError {
		if let message = ZXing_LastErrorMsg() {
			defer { ZXing_free(message) }
			return ZXingError(String(cString: message))
		}
		return ZXingError("Unknown ZXing error")
	}

	private func creatorOptionsJSONObject(from serialized: String) throws -> [String: Any] {
		let object = try JSONSerialization.jsonObject(with: Data(serialized.utf8))
		return try XCTUnwrap(object as? [String: Any])
	}

	#if canImport(CoreImage)
	private func rawByteQRCodeCGImage() throws -> CGImage {
		let context = CIContext()
		let filter = CIFilter.qrCodeGenerator()
		filter.message = Data([0xE9])
		filter.correctionLevel = "H"

		guard let outputImage = filter.outputImage else {
			throw ZXingError("Could not generate raw-byte QR fixture")
		}

		let scaledImage = outputImage.transformed(by: .init(scaleX: 12, y: 12))
		guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else {
			throw ZXingError("Could not render raw-byte QR fixture")
		}
		return cgImage
	}
	#endif

	private func expectedEnabledFormats(_ formats: [BarcodeFormat]) -> Set<BarcodeFormat> {
		Set(formats).intersection(BarcodeFormat.all(matching: .all))
	}
}
