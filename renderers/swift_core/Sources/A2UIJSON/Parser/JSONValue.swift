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

public enum JSONValue: Codable, Sendable, Equatable {
  case null
  case boolean(Bool)
  case number(Double)
  case string(String)
  case array([JSONValue])
  case object([String: JSONValue])

  public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    if container.decodeNil() {
      self = .null
    } else if let boolVal = try? container.decode(Bool.self) {
      self = .boolean(boolVal)
    } else if let doubleVal = try? container.decode(Double.self) {
      self = .number(doubleVal)
    } else if let stringVal = try? container.decode(String.self) {
      self = .string(stringVal)
    } else if let arrayVal = try? container.decode([JSONValue].self) {
      self = .array(arrayVal)
    } else if let objectVal = try? container.decode([String: JSONValue].self) {
      self = .object(objectVal)
    } else {
      throw DecodingError.dataCorruptedError(
        in: container,
        debugDescription: "Unknown JSON value type"
      )
    }
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    switch self {
    case .null:
      try container.encodeNil()
    case .boolean(let val):
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
    case .number: return "number"
    case .string: return "string"
    case .array: return "array"
    case .object: return "object"
    }
  }

  public static func == (lhs: JSONValue, rhs: JSONValue) -> Bool {
    switch (lhs, rhs) {
    case (.null, .null): return true
    case (.boolean(let l), .boolean(let r)): return l == r
    case (.number(let l), .number(let r)): return l == r
    case (.string(let l), .string(let r)):
      return l.utf8.elementsEqual(r.utf8)
    case (.array(let l), .array(let r)): return l == r
    case (.object(let l), .object(let r)): return l == r
    default: return false
    }
  }
}

