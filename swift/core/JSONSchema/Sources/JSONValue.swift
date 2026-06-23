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

public enum JSONValue: Codable, Sendable, Hashable {
  case null
  case boolean(Bool)
  case integer(Int)
  case number(Double)
  case string(String)
  case array([JSONValue])
  case object([String: JSONValue])

  public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    if container.decodeNil() {
      self = .null
      return
    }
    if let boolVal = try? container.decode(Bool.self) {
      self = .boolean(boolVal)
      return
    }
    if let intVal = try? container.decode(Int.self) {
      self = .integer(intVal)
      return
    }
    if let doubleVal = try? container.decode(Double.self) {
      self = .number(doubleVal)
      return
    }
    if let stringVal = try? container.decode(String.self) {
      self = .string(stringVal)
      return
    }
    do {
      self = .array(try container.decode([JSONValue].self))
      return
    } catch let error as DecodingError {
      if case .typeMismatch(_, let context) = error,
        context.codingPath.count == decoder.codingPath.count
      {
        // Not an array, try next type
      } else {
        throw error
      }
    }
    do {
      self = .object(try container.decode([String: JSONValue].self))
      return
    } catch let error as DecodingError {
      if case .typeMismatch(_, let context) = error,
        context.codingPath.count == decoder.codingPath.count
      {
        // Not an object, try next type
      } else {
        throw error
      }
    }
    throw DecodingError.dataCorruptedError(
      in: container,
      debugDescription: "Unknown JSON value type"
    )
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    switch self {
    case .null:
      try container.encodeNil()
    case .boolean(let val):
      try container.encode(val)
    case .integer(let val):
      try container.encode(val)
    case .number(let val):
      try container.encode(val)
    case .string(let val):
      try container.encode(val)
    case .array(let val):
      try container.encode(val)
    case .object(let val):
      try container.encode(val)
    }
  }

  public var typeName: String {
    switch self {
    case .null: return "null"
    case .boolean: return "boolean"
    case .integer: return "integer"
    case .number: return "number"
    case .string: return "string"
    case .array: return "array"
    case .object: return "object"
    }
  }

  /// Decodes a JSON string or data into a JSONValue, using standard JSONDecoder.
  public static func decode(from data: Data) throws -> JSONValue {
    return try JSONDecoder().decode(JSONValue.self, from: data)
  }

  /// Returns the double value if the JSONValue is a number or integer, nil otherwise.
  public var doubleValue: Double? {
    switch self {
    case .integer(let val):
      return Double(val)
    case .number(let val):
      return val
    default:
      return nil
    }
  }

  /// Compares two numeric JSONValues safely, avoiding Double precision loss if both are integers.
  /// Returns a ComparisonResult, or nil if either value is not numeric.
  public func compareNumeric(to other: JSONValue) -> ComparisonResult? {
    switch (self, other) {
    case (.integer(let l), .integer(let r)):
      if l < r { return .orderedAscending }
      if l > r { return .orderedDescending }
      return .orderedSame
    case (.number(let l), .number(let r)):
      if l < r { return .orderedAscending }
      if l > r { return .orderedDescending }
      return .orderedSame
    case (.integer(let l), .number(let r)):
      let lDouble = Double(l)
      if lDouble < r { return .orderedAscending }
      if lDouble > r { return .orderedDescending }
      return .orderedSame
    case (.number(let l), .integer(let r)):
      let rDouble = Double(r)
      if l < rDouble { return .orderedAscending }
      if l > rDouble { return .orderedDescending }
      return .orderedSame
    default:
      return nil
    }
  }

  public static func == (lhs: JSONValue, rhs: JSONValue) -> Bool {
    switch (lhs, rhs) {
    case (.null, .null):
      return true
    case (.boolean(let l), .boolean(let r)):
      return l == r
    case (.string(let l), .string(let r)):
      return l == r
    case (.array(let l), .array(let r)):
      return l == r
    case (.object(let l), .object(let r)):
      return l == r
    default:
      if let comp = lhs.compareNumeric(to: rhs) {
        return comp == .orderedSame
      }
      return false
    }
  }

  public func hash(into hasher: inout Hasher) {
    switch self {
    case .null:
      hasher.combine(0)
    case .boolean(let val):
      hasher.combine(val)
    case .integer(let val):
      hasher.combine(Double(val))
    case .number(let val):
      hasher.combine(val)
    case .string(let val):
      hasher.combine(val)
    case .array(let val):
      hasher.combine(val)
    case .object(let val):
      hasher.combine(val)
    }
  }
}
