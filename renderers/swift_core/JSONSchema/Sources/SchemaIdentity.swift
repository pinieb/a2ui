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

/// Represents the identity of a JSON Schema node, combining a Base URI and a JSON Pointer.
public struct SchemaIdentity: Sendable, Equatable, Hashable {
  /// The base URI of the schema (represented as a String to support arbitrary
  /// URNs or relative reference URI strings without pre-parsing failures).
  public let baseURI: String

  /// The JSON Pointer path within the schema.
  public let pointer: JSONPointer

  /// An empty SchemaIdentity.
  public static let empty = SchemaIdentity(uncheckedBaseURI: "")

  /// Initializes a SchemaIdentity with a base URI and optional JSON Pointer, without validation or parsing.
  internal init(uncheckedBaseURI baseURI: String, pointer: JSONPointer = JSONPointer()) {
    if baseURI.hasSuffix("#") {
      self.baseURI = String(baseURI.dropLast())
    } else {
      self.baseURI = baseURI
    }
    self.pointer = pointer
  }

  /// Initializes a SchemaIdentity with a base URI and optional JSON Pointer.
  /// Normalizes the baseURI by splitting it if it contains a fragment and merging it.
  /// - Parameters:
  ///   - baseURI: The base URI.
  ///   - pointer: The JSON Pointer.
  public init?(baseURI: String, pointer: JSONPointer = JSONPointer()) {
    let parts = baseURI.components(separatedBy: "#")
    let rawBase = parts.first ?? ""
    if rawBase.hasSuffix("#") {
      self.baseURI = String(rawBase.dropLast())
    } else {
      self.baseURI = rawBase
    }

    if parts.count > 1 {
      let fragment = "#" + parts[1...].joined(separator: "#")
      guard let basePointer = JSONPointer(stringRepresentation: fragment) else {
        return nil
      }
      self.pointer = JSONPointer(segments: basePointer.segments + pointer.segments)
    } else {
      self.pointer = pointer
    }
  }

  /// Initializes a SchemaIdentity by parsing a full URI string containing an optional fragment.
  /// - Parameter uri: The full URI string (e.g., "https://example.com/schema#/properties/name").
  public init?(uri: String) {
    let parts = uri.components(separatedBy: "#")
    let rawBase = parts.first ?? ""
    if rawBase.hasSuffix("#") {
      self.baseURI = String(rawBase.dropLast())
    } else {
      self.baseURI = rawBase
    }

    if parts.count > 1 {
      let fragment = "#" + parts[1...].joined(separator: "#")
      guard let parsedPointer = JSONPointer(stringRepresentation: fragment) else {
        return nil
      }
      self.pointer = parsedPointer
    } else {
      self.pointer = JSONPointer()
    }
  }

  /// Combines the base URI and the JSON Pointer.
  public var fullURI: String {
    return baseURI + pointer.stringRepresentation
  }

  /// Appends a new path segment to the JSON Pointer, returning a new SchemaIdentity.
  /// - Parameter path: The unescaped path segment to append.
  /// - Returns: A new SchemaIdentity with the updated pointer.
  public func appending(path: String) -> SchemaIdentity {
    return SchemaIdentity(uncheckedBaseURI: baseURI, pointer: pointer.appending(segment: path))
  }

  /// Updates the base URI and resets the JSON Pointer to empty (used when $id is encountered).
  /// - Parameter newURI: The new absolute base URI.
  /// - Returns: A new SchemaIdentity with the updated base URI and an empty pointer.
  public func updatingBaseURI(to newURI: String) -> SchemaIdentity {
    return SchemaIdentity(uncheckedBaseURI: newURI, pointer: JSONPointer())
  }
}
