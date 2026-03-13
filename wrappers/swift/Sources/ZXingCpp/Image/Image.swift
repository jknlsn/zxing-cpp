// Copyright 2026 Axel Waggershauser
// SPDX-License-Identifier: Apache-2.0

import Foundation
import ZXingCBridge

/// An owned image returned by barcode writing operations.
///
/// `@unchecked Sendable` safety rationale: The underlying C++ `Image` class owns its pixel data
/// via `std::unique_ptr<uint8_t[]>` and is immutable after construction. All C API accessors
/// (`ZXing_Image_width`, `_height`, `_format`, `_data`) take `const ZXing_Image*` and perform
/// no mutation, making concurrent reads safe.
public final class Image: @unchecked Sendable, CustomDebugStringConvertible {
	internal let _handle: OpaquePointer

	internal init(_ handle: OpaquePointer) {
		_handle = handle
	}

	deinit {
		ZXing_Image_delete(_handle)
	}

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
