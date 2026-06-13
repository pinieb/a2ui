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

/// Represents an object dependency constraint.
public enum Dependency: Codable, Equatable, Sendable {
  case property([String])
  case schema(JSONSchema)

  public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    if let stringArray = try? container.decode([String].self) {
      self = .property(stringArray)
    } else if let schemaVal = try? container.decode(JSONSchema.self) {
      self = .schema(schemaVal)
    } else {
      throw DecodingError.dataCorruptedError(
        in: container,
        debugDescription: "Invalid dependency: expected string array or schema"
      )
    }
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    switch self {
    case .property(let keys):
      try container.encode(keys)
    case .schema(let schema):
      try container.encode(schema)
    }
  }
}
