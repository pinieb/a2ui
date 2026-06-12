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

public struct JSONSchema {
  public static func parse(_ schemaString: String) throws -> SchemaType {
    let data = Data(schemaString.utf8)
    let rawSchema = try JSONDecoder().decode(RawSchema.self, from: data)
    return try mapToSchemaType(rawSchema)
  }
}

// MARK: - Private Parser Models

private enum RawType: Decodable, Sendable {
  case single(String)
  case array([String])

  init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    if let singleStr = try? container.decode(String.self) {
      self = .single(singleStr)
    } else if let arrayStrs = try? container.decode([String].self) {
      self = .array(arrayStrs)
    } else {
      throw DecodingError.dataCorruptedError(
        in: container,
        debugDescription: "Invalid type value: expected string or array of strings"
      )
    }
  }
}

private enum RawItems: Decodable, Sendable {
  case single(RawSchema)
  case array([RawSchema])

  init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    if let singleSchema = try? container.decode(RawSchema.self) {
      self = .single(singleSchema)
    } else if let arraySchemas = try? container.decode([RawSchema].self) {
      self = .array(arraySchemas)
    } else {
      throw DecodingError.dataCorruptedError(
        in: container,
        debugDescription: "Invalid items value: expected schema or array of schemas"
      )
    }
  }
}

private indirect enum RawSchema: Decodable, Sendable {
  case boolean(Bool)
  case object(ObjectSchema)

  init(from decoder: Decoder) throws {
    if let container = try? decoder.singleValueContainer(),
       let boolVal = try? container.decode(Bool.self) {
      self = .boolean(boolVal)
      return
    }
    let obj = try ObjectSchema(from: decoder)
    self = .object(obj)
  }
}

private enum RawAdditionalProperties: Decodable, Sendable {
  case boolean(Bool)
  case schema(RawSchema)

  init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    if let boolVal = try? container.decode(Bool.self) {
      self = .boolean(boolVal)
    } else if let schemaVal = try? container.decode(RawSchema.self) {
      self = .schema(schemaVal)
    } else {
      throw DecodingError.dataCorruptedError(
        in: container,
        debugDescription: "Invalid additionalProperties: expected boolean or schema"
      )
    }
  }
}

private enum RawDependency: Decodable, Sendable {
  case property([String])
  case schema(RawSchema)

  init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    if let stringArray = try? container.decode([String].self) {
      self = .property(stringArray)
    } else if let rawSchema = try? container.decode(RawSchema.self) {
      self = .schema(rawSchema)
    } else {
      throw DecodingError.dataCorruptedError(
        in: container,
        debugDescription: "Invalid dependency: expected an array of strings or a schema"
      )
    }
  }
}

private struct ObjectSchema: Decodable, Sendable {
  var type: RawType? = nil
  var properties: [String: RawSchema]? = nil
  var patternProperties: [String: RawSchema]? = nil
  var required: [String]? = nil
  var anyOf: [RawSchema]? = nil
  var allOf: [RawSchema]? = nil
  var oneOf: [RawSchema]? = nil
  var not: RawSchema? = nil
  var ref: String? = nil
  var id: String? = nil
  var items: RawItems? = nil
  var const: JSONValue? = nil
  var `enum`: [JSONValue]? = nil
  var additionalProperties: RawAdditionalProperties? = nil
  var uniqueItems: Bool? = nil
  var `if`: RawSchema? = nil
  var `then`: RawSchema? = nil
  var `else`: RawSchema? = nil
  var contains: RawSchema? = nil
  var propertyNames: RawSchema? = nil
  var dependencies: [String: RawDependency]? = nil

  init() {}

  private enum CodingKeys: String, CodingKey {
    case type
    case properties
    case patternProperties
    case required
    case anyOf
    case allOf
    case oneOf
    case not
    case ref = "$ref"
    case id = "$id"
    case items
    case const
    case `enum` = "enum"
    case additionalProperties
    case uniqueItems
    case `if` = "if"
    case `then` = "then"
    case `else` = "else"
    case contains
    case propertyNames
    case dependencies
  }
}

private func mapToSchemaType(_ raw: RawSchema) throws -> SchemaType {
  switch raw {
  case .boolean(let value):
    return value ? SchemaAny() : SchemaNone()
  case .object(let obj):
    return try mapObjectSchemaToSchemaType(obj)
  }
}

private func mapObjectSchemaToSchemaType(_ raw: ObjectSchema) throws -> SchemaType {
  if let ref = raw.ref {
    return SchemaReference(ExternalSchemaStub(uri: ref))
  }

  // 1. If type is an array of strings, map to SchemaAnyOf of the individual types!
  let typedSchema: SchemaType
  let isImplicitType = (raw.type == nil)

  if let rawType = raw.type, case .array(let typeStrings) = rawType {
    let subschemas = try typeStrings.map { typeStr -> SchemaType in
      var dummy = ObjectSchema()
      dummy.type = .single(typeStr)
      dummy.properties = raw.properties
      dummy.patternProperties = raw.patternProperties
      dummy.required = raw.required
      dummy.items = raw.items
      dummy.additionalProperties = raw.additionalProperties
      dummy.uniqueItems = raw.uniqueItems
      return try mapObjectSchemaToSchemaType(dummy)
    }
    typedSchema = SchemaAnyOf(subschemas)
  } else {
    // Resolve implicit type or return SchemaAny for wildcards
    let type: String
    if let rawType = raw.type, case .single(let typeStr) = rawType {
      type = typeStr
    } else if raw.properties != nil || raw.patternProperties != nil || raw.required != nil || raw.additionalProperties != nil {
      type = "object"
    } else if raw.items != nil || raw.uniqueItems != nil {
      type = "array"
    } else {
      type = "any"
    }

    switch type {
    case "string":
      typedSchema = SchemaString()
    case "integer":
      typedSchema = SchemaInteger()
    case "boolean":
      typedSchema = SchemaBoolean()
    case "number":
      typedSchema = SchemaNumber()
    case "null":
      typedSchema = SchemaNull()
    case "array":
      let unique = raw.uniqueItems ?? false
      guard let rawItems = raw.items else {
        typedSchema = SchemaArray(items: SchemaAny(), omitType: isImplicitType, uniqueItems: unique)
        break
      }
      switch rawItems {
      case .single(let schema):
        let itemsSchema = try mapToSchemaType(schema)
        typedSchema = SchemaArray(items: itemsSchema, omitType: isImplicitType, uniqueItems: unique)
      case .array(let schemas):
        let itemSchemas = try schemas.map { try mapToSchemaType($0) }
        typedSchema = SchemaArray(itemArray: itemSchemas, omitType: isImplicitType, uniqueItems: unique)
      }
    case "object":
      var properties: [SchemaProperty] = []
      let requiredSet = Set(raw.required ?? [])
      if let rawProps = raw.properties {
        for (name, rawProp) in rawProps {
          let propType = try mapToSchemaType(rawProp)
          let isRequired = requiredSet.contains(name)
          properties.append(
            SchemaProperty(name: name, type: propType, isRequired: isRequired)
          )
        }
      }
      let additionalPropertiesSchema: SchemaType?
      if let rawAdditional = raw.additionalProperties {
        switch rawAdditional {
        case .boolean(let allowed):
          additionalPropertiesSchema = allowed ? nil : SchemaNone()
        case .schema(let rawSchema):
          additionalPropertiesSchema = try mapToSchemaType(rawSchema)
        }
      } else {
        additionalPropertiesSchema = nil
      }

      var patternProps: [SchemaPatternProperty]? = nil
      if let rawPatternProps = raw.patternProperties {
        var tempPatternProps: [SchemaPatternProperty] = []
        for (pattern, rawProp) in rawPatternProps {
          let propType = try mapToSchemaType(rawProp)
          tempPatternProps.append(SchemaPatternProperty(pattern: pattern, type: propType))
        }
        patternProps = tempPatternProps
      }

      typedSchema = SchemaObject(
        omitType: isImplicitType,
        additionalProperties: additionalPropertiesSchema,
        patternProperties: patternProps,
        properties: properties
      )
    case "any":
      typedSchema = SchemaAny()
    default:
      throw DecodingError.dataCorrupted(
        DecodingError.Context(
          codingPath: [],
          debugDescription: "Unsupported schema type: \(type)"
        )
      )
    }
  }

  var schemas: [SchemaType] = []
  if !(typedSchema is SchemaAny) {
    schemas.append(typedSchema)
  }
  if let const = raw.const {
    schemas.append(SchemaConst(const))
  }
  if let enumValues = raw.enum {
    schemas.append(SchemaEnum(enumValues))
  }
  if let allOf = raw.allOf {
    let subschemas = try allOf.map { try mapToSchemaType($0) }
    schemas.append(SchemaAllOf(subschemas))
  }
  if let anyOf = raw.anyOf {
    let subschemas = try anyOf.map { try mapToSchemaType($0) }
    schemas.append(SchemaAnyOf(subschemas))
  }
  if let oneOf = raw.oneOf {
    let subschemas = try oneOf.map { try mapToSchemaType($0) }
    schemas.append(SchemaOneOf(subschemas))
  }
  if let not = raw.not {
    let subschema = try mapToSchemaType(not)
    schemas.append(SchemaNot(subschema))
  }
  if let ifRaw = raw.`if` {
    let ifSchema = try mapToSchemaType(ifRaw)
    let thenSchema = try raw.`then`.map { try mapToSchemaType($0) }
    let elseSchema = try raw.`else`.map { try mapToSchemaType($0) }
    schemas.append(SchemaIfThenElse(ifSchema: ifSchema, thenSchema: thenSchema, elseSchema: elseSchema))
  }
  if let containsRaw = raw.contains {
    let containsSchema = try mapToSchemaType(containsRaw)
    schemas.append(SchemaContains(containsSchema))
  }
  if let propertyNamesRaw = raw.propertyNames {
    let propertyNamesSchema = try mapToSchemaType(propertyNamesRaw)
    schemas.append(SchemaPropertyNames(propertyNamesSchema))
  }
  if let rawDeps = raw.dependencies {
    var mappedDeps: [String: SchemaDependencies.Dependency] = [:]
    for (key, rawDep) in rawDeps {
      switch rawDep {
      case .property(let keys):
        mappedDeps[key] = .property(keys)
      case .schema(let schema):
        let depSchema = try mapToSchemaType(schema)
        mappedDeps[key] = .schema(depSchema)
      }
    }
    schemas.append(SchemaDependencies(mappedDeps))
  }

  if schemas.isEmpty {
    return SchemaAny()
  } else if schemas.count == 1 {
    return schemas[0]
  } else {
    return SchemaAllOf(schemas)
  }
}
