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
public struct SchemaIdentity: Sendable, Equatable {
  /// The base URI of the schema (represented as a String to support arbitrary
  /// URNs or relative reference URI strings without pre-parsing failures).
  public let baseURI: String

  /// The JSON Pointer path within the schema.
  public let pointer: JSONPointer

  /// Initializes a SchemaIdentity with a base URI and optional JSON Pointer.
  /// - Parameters:
  ///   - baseURI: The base URI.
  ///   - pointer: The JSON Pointer.
  public init(baseURI: String, pointer: JSONPointer = JSONPointer()) {
    // Strip trailing '#' on the baseURI if present.
    if baseURI.hasSuffix("#") {
      self.baseURI = String(baseURI.dropLast())
    } else {
      self.baseURI = baseURI
    }
    self.pointer = pointer
  }

  /// Initializes a SchemaIdentity by parsing a full URI string containing an optional fragment.
  /// - Parameter uri: The full URI string (e.g., "https://example.com/schema#/properties/name").
  public init(uri: String) {
    let parts = uri.components(separatedBy: "#")
    let rawBase = parts.first ?? ""
    if rawBase.hasSuffix("#") {
      self.baseURI = String(rawBase.dropLast())
    } else {
      self.baseURI = rawBase
    }

    if parts.count > 1 {
      let fragment = "#" + parts[1...].joined(separator: "#")
      self.pointer = JSONPointer(stringRepresentation: fragment)
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
    return SchemaIdentity(baseURI: baseURI, pointer: pointer.appending(segment: path))
  }

  /// Updates the base URI and resets the JSON Pointer to empty (used when $id is encountered).
  /// - Parameter newURI: The new absolute base URI.
  /// - Returns: A new SchemaIdentity with the updated base URI and an empty pointer.
  public func updatingBaseURI(to newURI: String) -> SchemaIdentity {
    return SchemaIdentity(baseURI: newURI, pointer: JSONPointer())
  }
}
