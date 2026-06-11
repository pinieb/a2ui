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

/// The base protocol for all JSON Schema types.
/// Inherits from Encodable and Sendable to ensure type safety and thread
/// safety under Swift 6.
public protocol SchemaType: Encodable, Sendable {
  func validate(instance: JSONValue) throws -> ValidationOutput
}

public struct SchemaString: SchemaType {
  public init() {}

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode("string", forKey: .type)
  }

  public func validate(instance: JSONValue) throws -> ValidationOutput {
    switch instance {
    case .string:
      return ValidationOutput(instance: instance)
    default:
      throw ValidationError(
        path: "/",
        message: "Expected string, got \(instance.typeName)"
      )
    }
  }

  private enum CodingKeys: String, CodingKey {
    case type
  }
}

public struct SchemaInteger: SchemaType {
  public init() {}

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode("integer", forKey: .type)
  }

  public func validate(instance: JSONValue) throws -> ValidationOutput {
    switch instance {
    case .number(let value):
      if value == floor(value) {
        return ValidationOutput(instance: instance)
      } else {
        throw ValidationError(
          path: "/",
          message: "Expected integer, got number with fractional part: \(value)"
        )
      }
    default:
      throw ValidationError(
        path: "/",
        message: "Expected integer, got \(instance.typeName)"
      )
    }
  }

  private enum CodingKeys: String, CodingKey {
    case type
  }
}

public struct SchemaBoolean: SchemaType {
  public init() {}

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode("boolean", forKey: .type)
  }

  public func validate(instance: JSONValue) throws -> ValidationOutput {
    switch instance {
    case .boolean:
      return ValidationOutput(instance: instance)
    default:
      throw ValidationError(
        path: "/",
        message: "Expected boolean, got \(instance.typeName)"
      )
    }
  }

  private enum CodingKeys: String, CodingKey {
    case type
  }
}

public struct SchemaNumber: SchemaType {
  public init() {}

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode("number", forKey: .type)
  }

  public func validate(instance: JSONValue) throws -> ValidationOutput {
    switch instance {
    case .number:
      return ValidationOutput(instance: instance)
    default:
      throw ValidationError(
        path: "/",
        message: "Expected number, got \(instance.typeName)"
      )
    }
  }

  private enum CodingKeys: String, CodingKey {
    case type
  }
}

public struct SchemaArray: SchemaType {
  public let items: SchemaType?

  public init(items: SchemaType? = nil) {
    self.items = items
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode("array", forKey: .type)
    if let items {
      try container.encode(AnyEncodable(items), forKey: .items)
    }
  }

  public func validate(instance: JSONValue) throws -> ValidationOutput {
    guard case .array(let arrayItems) = instance else {
      throw ValidationError(
        path: "/",
        message: "Expected array, got \(instance.typeName)"
      )
    }
    var children: [String: ValidationOutput] = [:]
    if let items {
      for (index, item) in arrayItems.enumerated() {
        do {
          let childOutput = try items.validate(instance: item)
          children[String(index)] = childOutput
        } catch let error as ValidationError {
          let segment = String(index)
          let prependedPath =
            error.path == "/" ? "/\(segment)" : "/\(segment)\(error.path)"
          throw ValidationError(path: prependedPath, message: error.message)
        }
      }
    }
    return ValidationOutput(instance: instance, children: children)
  }

  private enum CodingKeys: String, CodingKey {
    case type
    case items
  }
}

/// A type-erased Encodable and Sendable wrapper used to encode
/// heterogeneous SchemaType existentials.
public struct AnyEncodable: Encodable, Sendable {
  private let encodeClosure: @Sendable (Encoder) throws -> Void

  public init<T: Encodable & Sendable>(_ value: T) {
    self.encodeClosure = { encoder in
      try value.encode(to: encoder)
    }
  }

  public func encode(to encoder: Encoder) throws {
    try encodeClosure(encoder)
  }
}

public struct SchemaConst: SchemaType {
  public let value: String
  public init(_ value: String) {
    self.value = value
  }
  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(value, forKey: .const)
  }
  public func validate(instance: JSONValue) throws -> ValidationOutput {
    guard case .string(let str) = instance, str == value else {
      throw ValidationError(
        path: "/",
        message: "Expected const '\(value)', got \(instance.typeName)"
      )
    }
    return ValidationOutput(instance: instance)
  }
  private enum CodingKeys: String, CodingKey {
    case const
  }
}
