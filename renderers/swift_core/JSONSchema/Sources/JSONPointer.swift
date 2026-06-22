// Copyright 2026 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Foundation

/// A utility to handle RFC 6901 JSON Pointer mechanics.
public struct JSONPointer: Sendable, Equatable {
  /// The unescaped path segments of the JSON Pointer.
  public let segments: [String]

  /// Initializes a new JSON Pointer with the given unescaped path segments.
  /// - Parameter segments: The list of unescaped segments.
  public init(segments: [String] = []) {
    self.segments = segments
  }

  /// Initializes a JSON Pointer by parsing its escaped string representation.
  /// - Parameter stringRepresentation: The escaped JSON Pointer string.
  public init(stringRepresentation: String) {
    var path = stringRepresentation
    let isFragment = path.hasPrefix("#")
    if isFragment {
      path = String(path.dropFirst())
    }

    if isFragment {
      path = path.removingPercentEncoding ?? path
    }

    if path.isEmpty {
      self.segments = []
      return
    }

    guard path.hasPrefix("/") else {
      self.segments = []
      return
    }

    let parts = path.components(separatedBy: "/")
    self.segments = parts.dropFirst().map { Self.unescape($0) }
  }

  /// Generates the valid escaped pointer string (e.g., "#/properties/user~0name").
  public var stringRepresentation: String {
    if segments.isEmpty {
      return "#"
    }
    let escaped = segments.map { Self.escape($0) }
    let rawPointer = "/" + escaped.joined(separator: "/")
    let encoded =
      rawPointer.addingPercentEncoding(
        withAllowedCharacters: .urlFragmentAllowed
      ) ?? rawPointer
    return "#" + encoded
  }

  /// Appends a new path segment, returning a new JSONPointer instance.
  /// - Parameter segment: The unescaped path segment to append.
  /// - Returns: A new JSONPointer with the appended segment.
  public func appending(segment: String) -> JSONPointer {
    return JSONPointer(segments: segments + [segment])
  }

  // MARK: - RFC 6901 Escaping / Unescaping

  /// Escapes a segment according to RFC 6901 (~ to ~0, / to ~1).
  private static func escape(_ segment: String) -> String {
    return
      segment
      .replacingOccurrences(of: "~", with: "~0")
      .replacingOccurrences(of: "/", with: "~1")
  }

  /// Unescapes a segment according to RFC 6901 (~1 to /, ~0 to ~).
  private static func unescape(_ segment: String) -> String {
    return
      segment
      .replacingOccurrences(of: "~1", with: "/")
      .replacingOccurrences(of: "~0", with: "~")
  }
}
