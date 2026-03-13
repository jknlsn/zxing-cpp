// Copyright 2026 Axel Waggershauser
// SPDX-License-Identifier: Apache-2.0

import Foundation
import ZXingCBridge

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
		pointer: UnsafePointer<UInt8>?,
		size: Int,
		width: Int,
		height: Int,
		format: ImageFormat,
		rowStride: Int,
		pixStride: Int
	) throws -> OpaquePointer {
		let cSize = try checkedInt32(size, name: "ImageView size")
		let cWidth = try checkedInt32(width, name: "ImageView width")
		let cHeight = try checkedInt32(height, name: "ImageView height")
		let cRowStride = try checkedInt32(rowStride, name: "ImageView rowStride")
		let cPixStride = try checkedInt32(pixStride, name: "ImageView pixStride")
		let cFormat: ZXing_ImageFormat = try checkedCEnum(format.rawValue)
		guard let iv = ZXing_ImageView_new_checked(pointer, cSize, cWidth, cHeight, cFormat, cRowStride, cPixStride) else {
			throw lastError()
		}
		return iv
	}

	/// Creates an ImageView from Data without additional pixel buffer copying.
	public convenience init(data: Data, width: Int, height: Int, format: ImageFormat, rowStride: Int = 0, pixStride: Int = 0) throws {
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
		pointer: UnsafePointer<UInt8>,
		size: Int,
		width: Int,
		height: Int,
		format: ImageFormat,
		rowStride: Int = 0,
		pixStride: Int = 0,
		retaining source: AnyObject
	) throws {
		let handle = try Self.makeHandle(
			pointer: pointer,
			size: size,
			width: width,
			height: height,
			format: format,
			rowStride: rowStride,
			pixStride: pixStride
		)
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
