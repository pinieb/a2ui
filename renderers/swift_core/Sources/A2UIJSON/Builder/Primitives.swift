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
  public let itemArray: [SchemaType]?
  public let omitType: Bool
  public let uniqueItems: Bool

  public init(items: SchemaType? = nil, omitType: Bool = false, uniqueItems: Bool = false) {
    self.items = items
    self.itemArray = nil
    self.omitType = omitType
    self.uniqueItems = uniqueItems
  }

  public init(itemArray: [SchemaType], omitType: Bool = false, uniqueItems: Bool = false) {
    self.items = nil
    self.itemArray = itemArray
    self.omitType = omitType
    self.uniqueItems = uniqueItems
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    if !omitType {
      try container.encode("array", forKey: .type)
    }
    if let items {
      try container.encode(AnyEncodable(items), forKey: .items)
    } else if let itemArray {
      let encodableArray = itemArray.map { AnyEncodable($0) }
      try container.encode(encodableArray, forKey: .items)
    }
    if uniqueItems {
      try container.encode(true, forKey: .uniqueItems)
    }
  }

  public func validate(instance: JSONValue) throws -> ValidationOutput {
    guard case .array(let arrayItems) = instance else {
      if omitType {
        return ValidationOutput(instance: instance)
      } else {
        throw ValidationError(
          path: "/",
          message: "Expected array, got \(instance.typeName)"
        )
      }
    }
    if uniqueItems {
      for i in 0..<arrayItems.count {
        for j in (i + 1)..<arrayItems.count {
          if arrayItems[i] == arrayItems[j] {
            throw ValidationError(
              path: "/",
              message: "Array contains duplicate items at indices \(i) and \(j)"
            )
          }
        }
      }
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
    } else if let itemArray {
      for (index, item) in arrayItems.enumerated() {
        if index < itemArray.count {
          do {
            let childOutput = try itemArray[index].validate(instance: item)
            children[String(index)] = childOutput
          } catch let error as ValidationError {
            let segment = String(index)
            let prependedPath =
              error.path == "/" ? "/\(segment)" : "/\(segment)\(error.path)"
            throw ValidationError(path: prependedPath, message: error.message)
          }
        }
      }
    }
    return ValidationOutput(instance: instance, children: children)
  }

  private enum CodingKeys: String, CodingKey {
    case type
    case items
    case uniqueItems
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
  public let value: JSONValue
  public init(_ value: JSONValue) {
    self.value = value
  }
  public init(_ value: String) {
    self.value = .string(value)
  }
  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(value, forKey: .const)
  }
  public func validate(instance: JSONValue) throws -> ValidationOutput {
    guard instance == value else {
      throw ValidationError(
        path: "/",
        message: "Expected const '\(value)', got \(instance)"
      )
    }
    return ValidationOutput(instance: instance)
  }
  private enum CodingKeys: String, CodingKey {
    case const
  }
}

public struct SchemaEnum: SchemaType {
  public let values: [JSONValue]

  public init(_ values: [JSONValue]) {
    self.values = values
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(values, forKey: .enum)
  }

  public func validate(instance: JSONValue) throws -> ValidationOutput {
    guard values.contains(instance) else {
      throw ValidationError(
        path: "/",
        message: "Value \(instance) is not in enum \(values)"
      )
    }
    return ValidationOutput(instance: instance)
  }

  private enum CodingKeys: String, CodingKey {
    case `enum` = "enum"
  }
}

public struct SchemaAny: SchemaType {
  public init() {}

  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode([String: String]())
  }

  public func validate(instance: JSONValue) throws -> ValidationOutput {
    return ValidationOutput(instance: instance)
  }
}

public struct SchemaNone: SchemaType {
  public init() {}

  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(false)
  }

  public func validate(instance: JSONValue) throws -> ValidationOutput {
    throw ValidationError(
      path: "/",
      message: "Schema 'false' rejects all values"
    )
  }
}

public struct SchemaNull: SchemaType {
  public init() {}

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode("null", forKey: .type)
  }

  public func validate(instance: JSONValue) throws -> ValidationOutput {
    switch instance {
    case .null:
      return ValidationOutput(instance: instance)
    default:
      throw ValidationError(
        path: "/",
        message: "Expected null, got \(instance.typeName)"
      )
    }
  }

  private enum CodingKeys: String, CodingKey {
    case type
  }
}

public struct SchemaNot: SchemaType {
  public let subschema: SchemaType

  public init(_ subschema: SchemaType) {
    self.subschema = subschema
  }

  public init(subschema: SchemaType) {
    self.subschema = subschema
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(AnyEncodable(subschema), forKey: .not)
  }

  public func validate(instance: JSONValue) throws -> ValidationOutput {
    do {
      _ = try subschema.validate(instance: instance)
    } catch {
      return ValidationOutput(instance: instance)
    }
    throw ValidationError(
      path: "/",
      message: "Instance matched schema but 'not' was specified"
    )
  }

  private enum CodingKeys: String, CodingKey {
    case not
  }
}

public struct SchemaOneOf: SchemaType {
  public let subschemas: [SchemaType]

  public init(_ subschemas: [SchemaType]) {
    self.subschemas = subschemas
  }

  public init(subschemas: [SchemaType]) {
    self.subschemas = subschemas
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(
      subschemas.map { AnyEncodable($0) },
      forKey: .oneOf
    )
  }

  public func validate(instance: JSONValue) throws -> ValidationOutput {
    var matchedCount = 0
    var matchedOutput: ValidationOutput? = nil
    var errors: [ValidationError] = []

    for subschema in subschemas {
      do {
        let output = try subschema.validate(instance: instance)
        matchedCount += 1
        if matchedCount > 1 {
          break
        }
        matchedOutput = output
      } catch let error as ValidationError {
        errors.append(error)
      } catch {
        errors.append(
          ValidationError(path: "/", message: String(describing: error))
        )
      }
    }

    if matchedCount > 1 {
      throw ValidationError(
        path: "/",
        message: "Instance matched multiple subschemas in oneOf, expected exactly 1 (early abort)"
      )
    }

    if let matchedOutput {
      return matchedOutput
    }

    if errors.isEmpty {
      throw ValidationError(
        path: "/",
        message: "Instance did not match any subschema in oneOf"
      )
    }

    let depst = errors.map { ($0, $0.path.split(separator: "/").count) }
    if let maxDepth = depst.map({ $1 }).max() {
      let deepestErrors = depst.filter { $1 == maxDepth }.map { $0.0 }
      if deepestErrors.count == 1 {
        throw deepestErrors[0]
      } else {
        let firstPath = deepestErrors[0].path
        let allPathsEqual = deepestErrors.allSatisfy { $0.path == firstPath }
        let combinedMessage =
          "Instance did not match any subschema in oneOf: ["
          + deepestErrors.map { $0.message }.joined(separator: ", ")
          + "]"
        if allPathsEqual {
          throw ValidationError(
            path: firstPath,
            message: combinedMessage
          )
        } else {
          throw ValidationError(
            path: "/",
            message: combinedMessage
          )
        }
      }
    }

    throw ValidationError(
      path: "/",
      message: "Instance did not match any subschema in oneOf"
    )
  }

  private enum CodingKeys: String, CodingKey {
    case oneOf
  }
}

public struct SchemaPatternProperty: @unchecked Sendable {
  public let pattern: String
  public let regex: NSRegularExpression?
  public let type: SchemaType

  public init(pattern: String, type: SchemaType) {
    self.pattern = pattern
    self.type = type
    self.regex = try? NSRegularExpression(pattern: pattern, options: [])
  }
}

public struct SchemaIfThenElse: SchemaType {
  public let ifSchema: SchemaType
  public let thenSchema: SchemaType?
  public let elseSchema: SchemaType?

  public init(ifSchema: SchemaType, thenSchema: SchemaType? = nil, elseSchema: SchemaType? = nil) {
    self.ifSchema = ifSchema
    self.thenSchema = thenSchema
    self.elseSchema = elseSchema
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(AnyEncodable(ifSchema), forKey: .`if`)
    if let thenSchema {
      try container.encode(AnyEncodable(thenSchema), forKey: .`then`)
    }
    if let elseSchema {
      try container.encode(AnyEncodable(elseSchema), forKey: .`else`)
    }
  }

  public func validate(instance: JSONValue) throws -> ValidationOutput {
    var ifSucceeded = false
    var ifOutput: ValidationOutput? = nil
    do {
      ifOutput = try ifSchema.validate(instance: instance)
      ifSucceeded = true
    } catch {
      // ifSchema failed
    }

    if ifSucceeded {
      if let thenSchema {
        let thenOutput = try thenSchema.validate(instance: instance)
        if let ifOutput {
          return mergeValidationOutputs([ifOutput, thenOutput], instance: instance)
        } else {
          return thenOutput
        }
      } else {
        return ifOutput ?? ValidationOutput(instance: instance)
      }
    } else {
      if let elseSchema {
        return try elseSchema.validate(instance: instance)
      } else {
        return ValidationOutput(instance: instance)
      }
    }
  }

  private enum CodingKeys: String, CodingKey {
    case `if` = "if"
    case `then` = "then"
    case `else` = "else"
  }
}

public struct SchemaContains: SchemaType {
  public let schema: SchemaType

  public init(_ schema: SchemaType) {
    self.schema = schema
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(AnyEncodable(schema), forKey: .contains)
  }

  public func validate(instance: JSONValue) throws -> ValidationOutput {
    guard case .array(let arrayItems) = instance else {
      return ValidationOutput(instance: instance)
    }

    var children: [String: ValidationOutput] = [:]
    for (index, item) in arrayItems.enumerated() {
      if let output = try? schema.validate(instance: item) {
        children[String(index)] = output
      }
    }

    guard !children.isEmpty else {
      throw ValidationError(
        path: "/",
        message: "Array does not contain any element matching the schema"
      )
    }

    return ValidationOutput(instance: instance, children: children)
  }

  private enum CodingKeys: String, CodingKey {
    case contains
  }
}

public struct SchemaPropertyNames: SchemaType {
  public let schema: SchemaType

  public init(_ schema: SchemaType) {
    self.schema = schema
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(AnyEncodable(schema), forKey: .propertyNames)
  }

  public func validate(instance: JSONValue) throws -> ValidationOutput {
    guard case .object(let properties) = instance else {
      return ValidationOutput(instance: instance)
    }

    var children: [String: ValidationOutput] = [:]
    for key in properties.keys {
      let keyInstance = JSONValue.string(key)
      do {
        let childOutput = try schema.validate(instance: keyInstance)
        children[key] = childOutput
      } catch let error as ValidationError {
        let prependedPath = error.path == "/" ? "/\(key)" : "/\(key)\(error.path)"
        throw ValidationError(
          path: prependedPath,
          message: "Property name '\(key)' is invalid: \(error.message)"
        )
      }
    }

    return ValidationOutput(instance: instance, children: children)
  }

  private enum CodingKeys: String, CodingKey {
    case propertyNames
  }
}

public struct SchemaDependencies: SchemaType {
  public enum Dependency: Sendable {
    case property([String])
    case schema(SchemaType)
  }

  public let dependencies: [String: Dependency]

  public init(_ dependencies: [String: Dependency]) {
    self.dependencies = dependencies
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    var depsContainer = container.nestedContainer(keyedBy: DynamicCodingKeys.self, forKey: .dependencies)
    for (key, dependency) in dependencies {
      let codingKey = DynamicCodingKeys(stringValue: key)
      switch dependency {
      case .property(let keys):
        try depsContainer.encode(keys, forKey: codingKey)
      case .schema(let schema):
        try depsContainer.encode(AnyEncodable(schema), forKey: codingKey)
      }
    }
  }

  public func validate(instance: JSONValue) throws -> ValidationOutput {
    guard case .object(let properties) = instance else {
      return ValidationOutput(instance: instance)
    }

    var outputs: [ValidationOutput] = []

    for (triggerKey, dependency) in dependencies {
      if properties.keys.contains(triggerKey) {
        switch dependency {
        case .property(let requiredKeys):
          for reqKey in requiredKeys {
            if !properties.keys.contains(reqKey) {
              throw ValidationError(
                path: "/",
                message: "Dependency requirement not met: trigger key '\(triggerKey)' requires '\(reqKey)'"
              )
            }
          }
        case .schema(let schema):
          let output = try schema.validate(instance: instance)
          outputs.append(output)
        }
      }
    }

    if outputs.isEmpty {
      return ValidationOutput(instance: instance)
    } else {
      return mergeValidationOutputs(outputs, instance: instance)
    }
  }

  private enum CodingKeys: String, CodingKey {
    case dependencies
  }

  private struct DynamicCodingKeys: CodingKey {
    var stringValue: String
    init(stringValue: String) {
      self.stringValue = stringValue
    }
    var intValue: Int?
    init?(intValue: Int) {
      return nil
    }
  }
}



