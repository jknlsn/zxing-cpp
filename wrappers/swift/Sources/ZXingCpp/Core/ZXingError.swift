// Copyright 2026 Axel Waggershauser
// SPDX-License-Identifier: Apache-2.0

import Foundation

/// Error type for ZXing operations.
public struct ZXingError: Error, LocalizedError, CustomStringConvertible, Sendable {
	public let message: String
	public var description: String { message }
	public var errorDescription: String? { message }

	init(_ message: String) {
		self.message = message
	}
}
