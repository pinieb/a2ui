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

// MARK: - DSL Elements

/// Represents a property definition in an object schema.
public struct JSONSchemaProperty: Sendable {
  public let name: String
  public let schema: JSONSchema
  public let isRequired: Bool

  public init(name: String, schema: JSONSchema, isRequired: Bool = false) {
    self.name = name
    self.schema = schema
    self.isRequired = isRequired
  }

  /// Static factory method enabling leading-dot syntax in builders with direct schema
  public static func property(
    _ name: String,
    isRequired: Bool = false,
    _ schema: JSONSchema
  ) -> JSONSchemaProperty {
    JSONSchemaProperty(name: name, schema: schema, isRequired: isRequired)
  }

  /// Static factory method enabling leading-dot syntax in builders with closure
  public static func property(
    _ name: String,
    isRequired: Bool = false,
    _ builder: () -> JSONSchema
  ) -> JSONSchemaProperty {
    JSONSchemaProperty(name: name, schema: builder(), isRequired: isRequired)
  }
}

// MARK: - Result Builders

@resultBuilder
public struct JSONSchemaPropertyBuilder: Sendable {
  public static func buildExpression(_ expression: JSONSchemaProperty) -> JSONSchemaProperty {
    expression
  }
  public static func buildBlock(_ components: JSONSchemaProperty...) -> [JSONSchemaProperty] {
    return Array(components)
  }
}

@resultBuilder
public struct JSONSchemaArrayBuilder: Sendable {
  public static func buildExpression(_ expression: JSONSchema) -> JSONSchema {
    expression
  }
  public static func buildBlock(_ components: JSONSchema...) -> [JSONSchema] {
    return Array(components)
  }
}

// MARK: - JSONSchema Static Factories

extension JSONSchema {
  public static func anyOf(@JSONSchemaArrayBuilder _ builder: () -> [JSONSchema]) -> JSONSchema {
    JSONSchema(anyOf: builder())
  }

  public static func allOf(@JSONSchemaArrayBuilder _ builder: () -> [JSONSchema]) -> JSONSchema {
    JSONSchema(allOf: builder())
  }

  public static func oneOf(@JSONSchemaArrayBuilder _ builder: () -> [JSONSchema]) -> JSONSchema {
    JSONSchema(oneOf: builder())
  }

  public static func not(_ subschema: JSONSchema) -> JSONSchema {
    JSONSchema(not: Box(subschema))
  }

  public static func `if`(_ ifSchema: JSONSchema) -> JSONSchemaIfThenElseBuilder {
    JSONSchemaIfThenElseBuilder(ifSchema: ifSchema)
  }

  // Reference Factories
  public static func reference(uri: String) -> JSONSchema {
    JSONSchema(ref: uri)
  }

  public static func reference(_ uri: String) -> JSONSchema {
    JSONSchema(ref: uri)
  }

}

// MARK: - If-Then-Else Builder

public struct JSONSchemaIfThenElseBuilder {
  private let ifSchema: JSONSchema
  private var thenSchema: JSONSchema? = nil

  public init(ifSchema: JSONSchema) {
    self.ifSchema = ifSchema
  }

  public func then(_ schema: JSONSchema) -> JSONSchemaIfThenElseBuilder {
    var copy = self
    copy.thenSchema = schema
    return copy
  }

  public func `else`(_ schema: JSONSchema) -> JSONSchema {
    JSONSchema(
      if: Box(ifSchema),
      then: thenSchema.map { Box($0) },
      else: Box(schema)
    )
  }
}

// MARK: - Legacy Compatibility Builders

@available(*, deprecated, message: "Use JSONSchemaProperty instead")
public struct SchemaProperty: Sendable {
  public let name: String
  public let type: SchemaType
  public let isRequired: Bool

  public init(name: String, type: SchemaType, isRequired: Bool = false) {
    self.name = name
    self.type = type
    self.isRequired = isRequired
  }
}

@available(*, deprecated, message: "Use SchemaProperty instead")
public struct SchemaPatternProperty: Sendable {
  public let pattern: String
  public let type: SchemaType

  public init(pattern: String, type: SchemaType) {
    self.pattern = pattern
    self.type = type
  }
}

@available(*, deprecated, message: "Use JSONSchemaPropertyBuilder instead")
@resultBuilder
public struct SchemaBuilder {
  public static func buildBlock(_ components: SchemaProperty...) -> [SchemaProperty] {
    return Array(components)
  }
}

@available(*, deprecated, message: "Use JSONSchema.object(...) instead")
public struct SchemaObject: SchemaType {
  private let schema: JSONSchema

  public init(
    omitType: Bool = false,
    additionalProperties: Bool = true,
    patternProperties: [SchemaPatternProperty]? = nil,
    @SchemaBuilder _ builder: () -> [SchemaProperty]
  ) {
    let props = builder()
    var propDict: [String: JSONSchema] = [:]
    var reqSet = Set<String>()
    for prop in props {
      propDict[prop.name] = prop.type as? JSONSchema ?? JSONSchema(allOf: [prop.type as! JSONSchema])
      if prop.isRequired {
        reqSet.insert(prop.name)
      }
    }
    var patternDict: [String: JSONSchema]? = nil
    if let patternProperties {
      var temp: [String: JSONSchema] = [:]
      for patProp in patternProperties {
        temp[patProp.pattern] = patProp.type as? JSONSchema ?? JSONSchema(allOf: [patProp.type as! JSONSchema])
      }
      patternDict = temp
    }
    self.schema = JSONSchema(
      types: omitType ? nil : [.object],
      properties: propDict,
      omitType: omitType,
      required: reqSet.isEmpty ? nil : reqSet,
      additionalProperties: additionalProperties ? nil : Box(JSONSchema(booleanSchema: false)),
      patternProperties: patternDict
    )
  }

  public init(
    omitType: Bool = false,
    additionalProperties: SchemaType?,
    patternProperties: [SchemaPatternProperty]? = nil,
    @SchemaBuilder _ builder: () -> [SchemaProperty]
  ) {
    let props = builder()
    var propDict: [String: JSONSchema] = [:]
    var reqSet = Set<String>()
    for prop in props {
      propDict[prop.name] = prop.type as? JSONSchema ?? JSONSchema(allOf: [prop.type as! JSONSchema])
      if prop.isRequired {
        reqSet.insert(prop.name)
      }
    }
    var patternDict: [String: JSONSchema]? = nil
    if let patternProperties {
      var temp: [String: JSONSchema] = [:]
      for patProp in patternProperties {
        temp[patProp.pattern] = patProp.type as? JSONSchema ?? JSONSchema(allOf: [patProp.type as! JSONSchema])
      }
      patternDict = temp
    }
    self.schema = JSONSchema(
      types: omitType ? nil : [.object],
      properties: propDict,
      omitType: omitType,
      required: reqSet.isEmpty ? nil : reqSet,
      additionalProperties: additionalProperties.map { Box($0 as? JSONSchema ?? JSONSchema(allOf: [$0 as! JSONSchema])) },
      patternProperties: patternDict
    )
  }

  public func encode(to encoder: Encoder) throws {
    try schema.encode(to: encoder)
  }

  public func validate(instance: JSONValue) throws -> ValidationOutput {
    try schema.validate(instance: instance)
  }
}

// MARK: - Dependencies DSL

public struct JSONSchemaDependency: Sendable {
  public let triggerKey: String
  public let dependency: Dependency

  public static func dependency(_ triggerKey: String, keys: [String]) -> JSONSchemaDependency {
    JSONSchemaDependency(triggerKey: triggerKey, dependency: .property(keys))
  }

  public static func dependency(_ triggerKey: String, _ schema: JSONSchema) -> JSONSchemaDependency {
    JSONSchemaDependency(triggerKey: triggerKey, dependency: .schema(schema))
  }

  public static func dependency(_ triggerKey: String, _ builder: () -> JSONSchema) -> JSONSchemaDependency {
    JSONSchemaDependency(triggerKey: triggerKey, dependency: .schema(builder()))
  }
}

@resultBuilder
public struct JSONSchemaDependencyBuilder: Sendable {
  public static func buildExpression(_ expression: JSONSchemaDependency) -> JSONSchemaDependency {
    expression
  }
  public static func buildBlock(_ components: JSONSchemaDependency...) -> [JSONSchemaDependency] {
    Array(components)
  }
}

// MARK: - Pattern Properties DSL

public struct JSONSchemaPatternProperty: Sendable {
  public let pattern: String
  public let schema: JSONSchema

  public static func pattern(_ pattern: String, _ schema: JSONSchema) -> JSONSchemaPatternProperty {
    JSONSchemaPatternProperty(pattern: pattern, schema: schema)
  }

  public static func pattern(_ pattern: String, _ builder: () -> JSONSchema) -> JSONSchemaPatternProperty {
    JSONSchemaPatternProperty(pattern: pattern, schema: builder())
  }
}

@resultBuilder
public struct JSONSchemaPatternPropertyBuilder: Sendable {
  public static func buildExpression(_ expression: JSONSchemaPatternProperty) -> JSONSchemaPatternProperty {
    expression
  }
  public static func buildBlock(_ components: JSONSchemaPatternProperty...) -> [JSONSchemaPatternProperty] {
    Array(components)
  }
}

// MARK: - JSONSchema Fluent Modifiers for DSL

extension JSONSchema {
  public func dependencies(
    @JSONSchemaDependencyBuilder _ builder: () -> [JSONSchemaDependency]
  ) -> JSONSchema {
    var dict: [String: Dependency] = [:]
    for dep in builder() {
      dict[dep.triggerKey] = dep.dependency
    }
    return mutatingCopy(dependencies: dict)
  }

  public func patternProperties(
    @JSONSchemaPatternPropertyBuilder _ builder: () -> [JSONSchemaPatternProperty]
  ) -> JSONSchema {
    var dict: [String: JSONSchema] = [:]
    for patProp in builder() {
      dict[patProp.pattern] = patProp.schema
    }
    return mutatingCopy(patternProperties: dict)
  }
}

