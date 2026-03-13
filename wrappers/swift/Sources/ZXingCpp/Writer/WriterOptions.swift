// Copyright 2026 Axel Waggershauser
// SPDX-License-Identifier: Apache-2.0

import Foundation
import ZXingCBridge

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

func withCWriterOptions<T>(_ options: WriterOptions, _ body: (OpaquePointer) throws -> T) throws -> T {
	guard let handle = ZXing_WriterOptions_new() else { throw lastError() }
	defer { ZXing_WriterOptions_delete(handle) }

	ZXing_WriterOptions_setScale(handle, try checkedInt32(options.scale, name: "WriterOptions.scale"))
	ZXing_WriterOptions_setRotate(handle, try checkedInt32(options.rotate, name: "WriterOptions.rotate"))
	ZXing_WriterOptions_setAddHRT(handle, options.humanReadableText)
	ZXing_WriterOptions_setAddQuietZones(handle, options.addQuietZones)

	return try body(handle)
}
