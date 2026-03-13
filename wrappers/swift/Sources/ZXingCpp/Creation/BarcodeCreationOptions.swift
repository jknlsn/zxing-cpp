// Copyright 2026 Axel Waggershauser
// SPDX-License-Identifier: Apache-2.0

import Foundation

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
			extraEsc: extraEsc,
			readerInit: readerInit
		)
	}
}
