// Copyright 2026 Axel Waggershauser
// SPDX-License-Identifier: Apache-2.0

import Foundation
import ZXingCBridge

func c2s(_ ptr: UnsafeMutablePointer<CChar>?) -> String {
	guard let ptr else { return "" }
	let str = String(cString: ptr)
	ZXing_free(ptr)
	return str
}

func c2bytes(_ ptr: UnsafeMutablePointer<UInt8>?, _ len: Int32) -> Data {
	guard let ptr else { return Data() }
	defer { ZXing_free(ptr) }
	guard len > 0 else { return Data() }
	return Data(bytes: ptr, count: Int(len))
}

/// Retrieves the last error from the C library's thread-local error state.
///
/// - Important: call this on the same thread and immediately after a failing C API call.
func lastError() -> ZXingError {
	if let msg = ZXing_LastErrorMsg() {
		return ZXingError(c2s(msg))
	}
	return ZXingError("Unknown ZXing error")
}

func checkedInt32(_ value: Int, name: String) throws -> Int32 {
	guard value >= Int(Int32.min), value <= Int(Int32.max) else {
		throw ZXingError("\(name) exceeds the supported Int32 range")
	}
	return Int32(value)
}

func checkedUInt8BackedInt(_ value: Int, name: String) throws -> Int32 {
	guard value >= 0, value <= Int(UInt8.max) else {
		throw ZXingError("\(name) must be in 0...255")
	}
	return Int32(value)
}

func unknownCEnumError<T>(_ raw: Int32, type: T.Type = T.self) -> ZXingError {
	ZXingError(
		"Unknown C enum value \(raw) for \(T.self). This may indicate a version mismatch between the Swift wrapper and the native ZXing library."
	)
}

/// Bridge our Int32-based Swift types to/from C enum types (imported with UInt32 rawValue).
func cEnum<T: RawRepresentable>(_ v: Int32) -> T? where T.RawValue == UInt32 {
	T(rawValue: UInt32(bitPattern: v))
}

func checkedCEnum<T: RawRepresentable>(_ v: Int32) throws -> T where T.RawValue == UInt32 {
	guard let result: T = cEnum(v) else { throw unknownCEnumError(v, type: T.self) }
	return result
}

func sEnum<T: RawRepresentable>(_ v: T) -> Int32 where T.RawValue == UInt32 {
	Int32(bitPattern: v.rawValue)
}

func swiftEnum<T: RawRepresentable>(_ raw: Int32) -> T? where T.RawValue == Int32 {
	T(rawValue: raw)
}

func checkedSwiftEnum<T: RawRepresentable>(_ raw: Int32) throws -> T where T.RawValue == Int32 {
	guard let result: T = swiftEnum(raw) else { throw unknownCEnumError(raw, type: T.self) }
	return result
}

/// Returns the native zxing-cpp library version string.
public func version() -> String {
	guard let v = ZXing_Version() else { return "" }
	return String(cString: v)
}
