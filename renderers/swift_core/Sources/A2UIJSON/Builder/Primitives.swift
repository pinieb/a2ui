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
public protocol SchemaType: Codable, Sendable {
  func validate(instance: JSONValue) throws -> ValidationOutput
}

/// Supported JSON Schema types.
public enum JSONSchemaType: String, Codable, Sendable {
  case string
  case number
  case integer
  case boolean
  case object
  case array
  case null
}

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

/// A lightweight indirection wrapper for recursive struct properties.
public final class Box<Val: Codable & Equatable & Sendable>: Codable, Equatable, Sendable {
  public let value: Val
  public init(_ value: Val) {
    self.value = value
  }
  public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    self.value = try container.decode(Val.self)
  }
  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(value)
  }
  public static func == (lhs: Box<Val>, rhs: Box<Val>) -> Bool {
    lhs.value == rhs.value
  }
}

/// A unified, rich representation of a JSON Schema.
public final class JSONSchema: SchemaType, Codable, Equatable, @unchecked Sendable {
  // Core Types
  public let types: Set<JSONSchemaType>?
  
  // Object / Array Properties
  public let properties: [String: JSONSchema]?
  public let items: Box<JSONSchema>?
  public let itemArray: [JSONSchema]?
  public let omitType: Bool

  // Numeric Constraints
  public let minimum: Double?
  public let maximum: Double?
  public let exclusiveMinimum: Double?
  public let exclusiveMaximum: Double?
  public let multipleOf: Double?

  // String Constraints
  public let minLength: Int?
  public let maxLength: Int?
  public let pattern: String?
  public let regex: NSRegularExpression?

  // Array Constraints
  public let minItems: Int?
  public let maxItems: Int?
  public let uniqueItems: Bool?
  public let contains: Box<JSONSchema>?

  // Object Constraints
  public let minProperties: Int?
  public let maxProperties: Int?
  public let required: Set<String>?
  public let additionalProperties: Box<JSONSchema>?
  public let patternProperties: [String: JSONSchema]?
  public let propertyNames: Box<JSONSchema>?
  public let dependencies: [String: Dependency]?

  // Draft 2020-12
  public let prefixItems: [JSONSchema]?
  public let dependentSchemas: [String: JSONSchema]?
  public let dependentRequired: [String: Set<String>]?
  public let minContains: Int?
  public let maxContains: Int?
  public let defs: [String: JSONSchema]?
  public let unevaluatedProperties: Box<JSONSchema>?
  public let unevaluatedItems: Box<JSONSchema>?
  public let dynamicAnchor: String?
  public let dynamicRef: String?
  public internal(set) var resolvedBaseURI: URL?
  public weak var parent: JSONSchema? = nil


  // Applicators
  public let allOf: [JSONSchema]?
  public let anyOf: [JSONSchema]?
  public let oneOf: [JSONSchema]?
  public let not: Box<JSONSchema>?
  public let `if`: Box<JSONSchema>?
  public let `then`: Box<JSONSchema>?
  public let `else`: Box<JSONSchema>?

  // Universal Constraints
  public let const: JSONValue?
  public let `enum`: [JSONValue]?

  // Reference
  private let refValue: String?
  public let id: String?
  public let uniqueRefIdentifier: String?
  private let localSchemaGetter: (@Sendable () -> JSONSchema)?

  public var ref: String? {
    if let refValue { return refValue }
    return localSchemaGetter?().id ?? localSchemaGetter?().ref
  }

  public var localSchema: Box<JSONSchema>? {
    if let localSchemaGetter {
      return Box(localSchemaGetter())
    }
    return nil
  }
  
  // Custom boolean schema representation (true/false)
  public let isBooleanSchema: Bool?
  public let booleanSchemaValue: Bool?

  public init(
    types: Set<JSONSchemaType>? = nil,
    properties: [String: JSONSchema]? = nil,
    items: Box<JSONSchema>? = nil,
    itemArray: [JSONSchema]? = nil,
    omitType: Bool = false,
    minimum: Double? = nil,
    maximum: Double? = nil,
    exclusiveMinimum: Double? = nil,
    exclusiveMaximum: Double? = nil,
    multipleOf: Double? = nil,
    minLength: Int? = nil,
    maxLength: Int? = nil,
    pattern: String? = nil,
    regex: NSRegularExpression? = nil,
    minItems: Int? = nil,
    maxItems: Int? = nil,
    uniqueItems: Bool? = nil,
    contains: Box<JSONSchema>? = nil,
    minProperties: Int? = nil,
    maxProperties: Int? = nil,
    required: Set<String>? = nil,
    additionalProperties: Box<JSONSchema>? = nil,
    patternProperties: [String: JSONSchema]? = nil,
    propertyNames: Box<JSONSchema>? = nil,
    dependencies: [String: Dependency]? = nil,
    allOf: [JSONSchema]? = nil,
    anyOf: [JSONSchema]? = nil,
    oneOf: [JSONSchema]? = nil,
    not: Box<JSONSchema>? = nil,
    `if`: Box<JSONSchema>? = nil,
    `then`: Box<JSONSchema>? = nil,
    `else`: Box<JSONSchema>? = nil,
    const: JSONValue? = nil,
    `enum`: [JSONValue]? = nil,
    ref: String? = nil,
    id: String? = nil,
    uniqueRefIdentifier: String? = nil,
    localSchema: Box<JSONSchema>? = nil,
    localSchemaGetter: (@Sendable () -> JSONSchema)? = nil,
    isBooleanSchema: Bool? = nil,
    booleanSchemaValue: Bool? = nil,
    // Draft 2020-12
    prefixItems: [JSONSchema]? = nil,
    dependentSchemas: [String: JSONSchema]? = nil,
    dependentRequired: [String: Set<String>]? = nil,
    minContains: Int? = nil,
    maxContains: Int? = nil,
    defs: [String: JSONSchema]? = nil,
    unevaluatedProperties: Box<JSONSchema>? = nil,
    unevaluatedItems: Box<JSONSchema>? = nil,
    dynamicAnchor: String? = nil,
    dynamicRef: String? = nil
  ) {
    self.types = types
    self.properties = properties
    self.items = items
    self.itemArray = itemArray
    self.omitType = omitType
    self.minimum = minimum
    self.maximum = maximum
    self.exclusiveMinimum = exclusiveMinimum
    self.exclusiveMaximum = exclusiveMaximum
    self.multipleOf = multipleOf
    self.minLength = minLength
    self.maxLength = maxLength
    self.pattern = pattern
    if let regex {
      self.regex = regex
    } else if let pattern {
      self.regex = try? NSRegularExpression(pattern: pattern, options: [])
    } else {
      self.regex = nil
    }
    self.minItems = minItems
    self.maxItems = maxItems
    self.uniqueItems = uniqueItems
    self.contains = contains
    self.minProperties = minProperties
    self.maxProperties = maxProperties
    self.required = required
    self.additionalProperties = additionalProperties
    self.patternProperties = patternProperties
    self.propertyNames = propertyNames
    self.dependencies = dependencies
    self.allOf = allOf
    self.anyOf = anyOf
    self.oneOf = oneOf
    self.not = not
    self.if = `if`
    self.then = `then`
    self.else = `else`
    self.const = const
    self.enum = `enum`
    self.refValue = ref
    self.id = id
    self.uniqueRefIdentifier = uniqueRefIdentifier
    if let localSchemaGetter {
      self.localSchemaGetter = localSchemaGetter
    } else if let localSchema {
      self.localSchemaGetter = { @Sendable in localSchema.value }
    } else {
      self.localSchemaGetter = nil
    }
    self.isBooleanSchema = isBooleanSchema
    self.booleanSchemaValue = booleanSchemaValue

    // Draft 2020-12
    self.prefixItems = prefixItems
    self.dependentSchemas = dependentSchemas
    self.dependentRequired = dependentRequired
    self.minContains = minContains
    self.maxContains = maxContains
    self.defs = defs
    self.unevaluatedProperties = unevaluatedProperties
    self.unevaluatedItems = unevaluatedItems
    self.dynamicAnchor = dynamicAnchor
    self.dynamicRef = dynamicRef
    self.resolvedBaseURI = nil
  }

  public init(booleanSchema: Bool) {
    self.types = nil
    self.properties = nil
    self.items = nil
    self.itemArray = nil
    self.omitType = false
    self.minimum = nil
    self.maximum = nil
    self.exclusiveMinimum = nil
    self.exclusiveMaximum = nil
    self.multipleOf = nil
    self.minLength = nil
    self.maxLength = nil
    self.pattern = nil
    self.regex = nil
    self.minItems = nil
    self.maxItems = nil
    self.uniqueItems = nil
    self.contains = nil
    self.minProperties = nil
    self.maxProperties = nil
    self.required = nil
    self.additionalProperties = nil
    self.patternProperties = nil
    self.propertyNames = nil
    self.dependencies = nil
    self.allOf = nil
    self.anyOf = nil
    self.oneOf = nil
    self.not = nil
    self.if = nil
    self.then = nil
    self.else = nil
    self.const = nil
    self.enum = nil
    self.refValue = nil
    self.id = nil
    self.uniqueRefIdentifier = nil
    self.localSchemaGetter = nil
    self.isBooleanSchema = true
    self.booleanSchemaValue = booleanSchema

    // Draft 2020-12
    self.prefixItems = nil
    self.dependentSchemas = nil
    self.dependentRequired = nil
    self.minContains = nil
    self.maxContains = nil
    self.defs = nil
    self.unevaluatedProperties = nil
    self.unevaluatedItems = nil
    self.dynamicAnchor = nil
    self.dynamicRef = nil
    self.resolvedBaseURI = nil
  }

  private enum CodingKeys: String, CodingKey {
    case type
    case properties
    case items
    case minimum
    case maximum
    case exclusiveMinimum
    case exclusiveMaximum
    case multipleOf
    case minLength
    case maxLength
    case pattern
    case minItems
    case maxItems
    case uniqueItems
    case contains
    case minProperties
    case maxProperties
    case required
    case additionalProperties
    case patternProperties
    case propertyNames
    case dependencies
    case allOf
    case anyOf
    case oneOf
    case not
    case `if` = "if"
    case `then` = "then"
    case `else` = "else"
    case const
    case `enum` = "enum"
    case ref = "$ref"
    case id = "$id"

    // Draft 2020-12
    case prefixItems
    case dependentSchemas
    case dependentRequired
    case minContains
    case maxContains
    case defs = "$defs"
    case definitions
    case unevaluatedProperties
    case unevaluatedItems
    case dynamicAnchor = "$dynamicAnchor"
    case dynamicRef = "$dynamicRef"
  }

  public init(from decoder: Decoder) throws {
    if let container = try? decoder.singleValueContainer() {
      if let boolVal = try? container.decode(Bool.self) {
        self.types = nil
        self.properties = nil
        self.items = nil
        self.itemArray = nil
        self.omitType = false
        self.minimum = nil
        self.maximum = nil
        self.exclusiveMinimum = nil
        self.exclusiveMaximum = nil
        self.multipleOf = nil
        self.minLength = nil
        self.maxLength = nil
        self.pattern = nil
        self.regex = nil
        self.minItems = nil
        self.maxItems = nil
        self.uniqueItems = nil
        self.contains = nil
        self.minProperties = nil
        self.maxProperties = nil
        self.required = nil
        self.additionalProperties = nil
        self.patternProperties = nil
        self.propertyNames = nil
        self.dependencies = nil
        self.allOf = nil
        self.anyOf = nil
        self.oneOf = nil
        self.not = nil
        self.if = nil
        self.then = nil
        self.else = nil
        self.const = nil
        self.enum = nil
        self.refValue = nil
        self.id = nil
        self.uniqueRefIdentifier = nil
        self.localSchemaGetter = nil
        self.isBooleanSchema = true
        self.booleanSchemaValue = boolVal

        // Draft 2020-12
        self.prefixItems = nil
        self.dependentSchemas = nil
        self.dependentRequired = nil
        self.minContains = nil
        self.maxContains = nil
        self.defs = nil
        self.unevaluatedProperties = nil
        self.unevaluatedItems = nil
        self.dynamicAnchor = nil
        self.dynamicRef = nil
        self.resolvedBaseURI = nil
        return
      }
    }

    let container = try decoder.container(keyedBy: CodingKeys.self)

    if let typeContainer = try? container.decode(RawType.self, forKey: .type) {
      switch typeContainer {
      case .single(let str):
        if let typeVal = JSONSchemaType(rawValue: str) {
          self.types = [typeVal]
        } else {
          self.types = nil
        }
      case .array(let strs):
        self.types = Set(strs.compactMap { JSONSchemaType(rawValue: $0) })
      }
    } else {
      self.types = nil
    }

    self.properties = try container.decodeIfPresent([String: JSONSchema].self, forKey: .properties)

    if let itemsContainer = try? container.decode(RawItems.self, forKey: .items) {
      switch itemsContainer {
      case .single(let schema):
        self.items = Box(schema)
        self.itemArray = nil
      case .array(let schemas):
        self.items = nil
        self.itemArray = schemas
      }
    } else {
      self.items = nil
      self.itemArray = nil
    }

    self.omitType = false

    self.minimum = try container.decodeIfPresent(Double.self, forKey: .minimum)
    self.maximum = try container.decodeIfPresent(Double.self, forKey: .maximum)
    self.exclusiveMinimum = try container.decodeIfPresent(Double.self, forKey: .exclusiveMinimum)
    self.exclusiveMaximum = try container.decodeIfPresent(Double.self, forKey: .exclusiveMaximum)
    self.multipleOf = try container.decodeIfPresent(Double.self, forKey: .multipleOf)

    self.minLength = try container.decodeIfPresent(Int.self, forKey: .minLength)
    self.maxLength = try container.decodeIfPresent(Int.self, forKey: .maxLength)
    self.pattern = try container.decodeIfPresent(String.self, forKey: .pattern)
    if let pattern = self.pattern {
      self.regex = try? NSRegularExpression(pattern: pattern, options: [])
    } else {
      self.regex = nil
    }

    self.minItems = try container.decodeIfPresent(Int.self, forKey: .minItems)
    self.maxItems = try container.decodeIfPresent(Int.self, forKey: .maxItems)
    self.uniqueItems = try container.decodeIfPresent(Bool.self, forKey: .uniqueItems)
    self.contains = try container.decodeIfPresent(Box<JSONSchema>.self, forKey: .contains)

    self.minProperties = try container.decodeIfPresent(Int.self, forKey: .minProperties)
    self.maxProperties = try container.decodeIfPresent(Int.self, forKey: .maxProperties)

    if let reqArray = try container.decodeIfPresent([String].self, forKey: .required) {
      self.required = Set(reqArray)
    } else {
      self.required = nil
    }

    if let additionalPropsContainer = try? container.decode(RawAdditionalProperties.self, forKey: .additionalProperties) {
      switch additionalPropsContainer {
      case .boolean(let allowed):
        self.additionalProperties = allowed ? nil : Box(JSONSchema(booleanSchema: false))
      case .schema(let schema):
        self.additionalProperties = Box(schema)
      }
    } else {
      self.additionalProperties = nil
    }

    self.patternProperties = try container.decodeIfPresent([String: JSONSchema].self, forKey: .patternProperties)
    self.propertyNames = try container.decodeIfPresent(Box<JSONSchema>.self, forKey: .propertyNames)
    self.dependencies = try container.decodeIfPresent([String: Dependency].self, forKey: .dependencies)

    self.allOf = try container.decodeIfPresent([JSONSchema].self, forKey: .allOf)
    self.anyOf = try container.decodeIfPresent([JSONSchema].self, forKey: .anyOf)
    self.oneOf = try container.decodeIfPresent([JSONSchema].self, forKey: .oneOf)
    self.not = try container.decodeIfPresent(Box<JSONSchema>.self, forKey: .not)
    self.if = try container.decodeIfPresent(Box<JSONSchema>.self, forKey: .if)
    self.then = try container.decodeIfPresent(Box<JSONSchema>.self, forKey: .then)
    self.else = try container.decodeIfPresent(Box<JSONSchema>.self, forKey: .else)

    self.const = try Self.decodeConstValue(from: container)
    self.enum = try Self.decodeEnumValue(from: container)

    self.refValue = try container.decodeIfPresent(String.self, forKey: .ref)
    self.id = try container.decodeIfPresent(String.self, forKey: .id)
    self.uniqueRefIdentifier = nil
    self.localSchemaGetter = nil

    self.isBooleanSchema = nil
    self.booleanSchemaValue = nil

    // Draft 2020-12
    self.prefixItems = try container.decodeIfPresent([JSONSchema].self, forKey: .prefixItems)
    self.dependentSchemas = try container.decodeIfPresent([String: JSONSchema].self, forKey: .dependentSchemas)
    if let depReq = try container.decodeIfPresent([String: [String]].self, forKey: .dependentRequired) {
      self.dependentRequired = depReq.mapValues { Set($0) }
    } else {
      self.dependentRequired = nil
    }
    self.minContains = try container.decodeIfPresent(Int.self, forKey: .minContains)
    self.maxContains = try container.decodeIfPresent(Int.self, forKey: .maxContains)

    let parsedDefs = try container.decodeIfPresent([String: JSONSchema].self, forKey: .defs)
    let parsedDefinitions = try container.decodeIfPresent([String: JSONSchema].self, forKey: .definitions)
    self.defs = parsedDefs ?? parsedDefinitions

    self.unevaluatedProperties = try container.decodeIfPresent(Box<JSONSchema>.self, forKey: .unevaluatedProperties)
    self.unevaluatedItems = try container.decodeIfPresent(Box<JSONSchema>.self, forKey: .unevaluatedItems)
    self.dynamicAnchor = try container.decodeIfPresent(String.self, forKey: .dynamicAnchor)
    self.dynamicRef = try container.decodeIfPresent(String.self, forKey: .dynamicRef)
    self.resolvedBaseURI = nil
  }

  private static func decodeConstValue(from container: KeyedDecodingContainer<CodingKeys>) throws -> JSONValue? {
    guard container.contains(.const) else { return nil }
    if try container.decodeNil(forKey: .const) {
      return .null
    }
    return try container.decode(JSONValue.self, forKey: .const)
  }

  private static func decodeEnumValue(from container: KeyedDecodingContainer<CodingKeys>) throws -> [JSONValue]? {
    guard container.contains(.enum) else { return nil }
    if try container.decodeNil(forKey: .enum) {
      return nil
    }
    return try container.decode([JSONValue].self, forKey: .enum)
  }

  public func encode(to encoder: Encoder) throws {
    if isBooleanSchema == true, let booleanSchemaValue {
      var container = encoder.singleValueContainer()
      try container.encode(booleanSchemaValue)
      return
    }

    var container = encoder.container(keyedBy: CodingKeys.self)

    if let ref {
      try container.encode(ref, forKey: .ref)
    }

    if let id {
      try container.encode(id, forKey: .id)
    }

    if let types, !omitType {
      if types.count == 1, let singleType = types.first {
        try container.encode(singleType.rawValue, forKey: .type)
      } else {
        let sortedTypes = types.map { $0.rawValue }.sorted()
        try container.encode(sortedTypes, forKey: .type)
      }
    }

    if let properties, !properties.isEmpty {
      try container.encode(properties, forKey: .properties)
    }

    if let items {
      try container.encode(items, forKey: .items)
    } else if let itemArray, !itemArray.isEmpty {
      try container.encode(itemArray, forKey: .items)
    }

    try container.encodeIfPresent(minimum, forKey: .minimum)
    try container.encodeIfPresent(maximum, forKey: .maximum)
    try container.encodeIfPresent(exclusiveMinimum, forKey: .exclusiveMinimum)
    try container.encodeIfPresent(exclusiveMaximum, forKey: .exclusiveMaximum)
    try container.encodeIfPresent(multipleOf, forKey: .multipleOf)

    try container.encodeIfPresent(minLength, forKey: .minLength)
    try container.encodeIfPresent(maxLength, forKey: .maxLength)
    try container.encodeIfPresent(pattern, forKey: .pattern)

    try container.encodeIfPresent(minItems, forKey: .minItems)
    try container.encodeIfPresent(maxItems, forKey: .maxItems)
    try container.encodeIfPresent(uniqueItems, forKey: .uniqueItems)
    try container.encodeIfPresent(contains, forKey: .contains)

    try container.encodeIfPresent(minProperties, forKey: .minProperties)
    try container.encodeIfPresent(maxProperties, forKey: .maxProperties)

    if let required {
      let sortedRequired = Array(required).sorted()
      try container.encode(sortedRequired, forKey: .required)
    }

    if let additionalProperties {
      if additionalProperties.value.isBooleanSchema == true && additionalProperties.value.booleanSchemaValue == false {
        try container.encode(false, forKey: .additionalProperties)
      } else {
        try container.encode(additionalProperties, forKey: .additionalProperties)
      }
    }

    if let patternProperties, !patternProperties.isEmpty {
      try container.encode(patternProperties, forKey: .patternProperties)
    }

    try container.encodeIfPresent(propertyNames, forKey: .propertyNames)
    try container.encodeIfPresent(dependencies, forKey: .dependencies)

    try container.encodeIfPresent(allOf, forKey: .allOf)
    try container.encodeIfPresent(anyOf, forKey: .anyOf)
    try container.encodeIfPresent(oneOf, forKey: .oneOf)
    try container.encodeIfPresent(not, forKey: .not)
    try container.encodeIfPresent(self.if, forKey: .if)
    try container.encodeIfPresent(then, forKey: .then)
    try container.encodeIfPresent(self.else, forKey: .else)

    try container.encodeIfPresent(const, forKey: .const)
    try container.encodeIfPresent(self.enum, forKey: .enum)

    // Draft 2020-12
    if let prefixItems, !prefixItems.isEmpty {
      try container.encode(prefixItems, forKey: .prefixItems)
    }
    if let dependentSchemas, !dependentSchemas.isEmpty {
      try container.encode(dependentSchemas, forKey: .dependentSchemas)
    }
    if let dependentRequired, !dependentRequired.isEmpty {
      let sortedDepReq = dependentRequired.mapValues { Array($0).sorted() }
      try container.encode(sortedDepReq, forKey: .dependentRequired)
    }
    try container.encodeIfPresent(minContains, forKey: .minContains)
    try container.encodeIfPresent(maxContains, forKey: .maxContains)
    if let defs, !defs.isEmpty {
      try container.encode(defs, forKey: .defs)
    }
    try container.encodeIfPresent(unevaluatedProperties, forKey: .unevaluatedProperties)
    try container.encodeIfPresent(unevaluatedItems, forKey: .unevaluatedItems)
    try container.encodeIfPresent(dynamicAnchor, forKey: .dynamicAnchor)
    try container.encodeIfPresent(dynamicRef, forKey: .dynamicRef)
  }

  public static func == (lhs: JSONSchema, rhs: JSONSchema) -> Bool {
    if lhs.isBooleanSchema != rhs.isBooleanSchema { return false }
    if lhs.booleanSchemaValue != rhs.booleanSchemaValue { return false }
    if lhs.types != rhs.types { return false }
    if lhs.properties != rhs.properties { return false }
    if lhs.items != rhs.items { return false }
    if lhs.itemArray != rhs.itemArray { return false }
    if lhs.omitType != rhs.omitType { return false }
    if lhs.minimum != rhs.minimum { return false }
    if lhs.maximum != rhs.maximum { return false }
    if lhs.exclusiveMinimum != rhs.exclusiveMinimum { return false }
    if lhs.exclusiveMaximum != rhs.exclusiveMaximum { return false }
    if lhs.multipleOf != rhs.multipleOf { return false }
    if lhs.minLength != rhs.minLength { return false }
    if lhs.maxLength != rhs.maxLength { return false }
    if lhs.pattern != rhs.pattern { return false }
    if lhs.minItems != rhs.minItems { return false }
    if lhs.maxItems != rhs.maxItems { return false }
    if lhs.uniqueItems != rhs.uniqueItems { return false }
    if lhs.contains != rhs.contains { return false }
    if lhs.minProperties != rhs.minProperties { return false }
    if lhs.maxProperties != rhs.maxProperties { return false }
    if lhs.required != rhs.required { return false }
    if lhs.additionalProperties != rhs.additionalProperties { return false }
    if lhs.patternProperties != rhs.patternProperties { return false }
    if lhs.propertyNames != rhs.propertyNames { return false }
    if lhs.dependencies != rhs.dependencies { return false }
    if lhs.allOf != rhs.allOf { return false }
    if lhs.anyOf != rhs.anyOf { return false }
    if lhs.oneOf != rhs.oneOf { return false }
    if lhs.not != rhs.not { return false }
    if lhs.if != rhs.if { return false }
    if lhs.then != rhs.then { return false }
    if lhs.else != rhs.else { return false }
    if lhs.const != rhs.const { return false }
    if lhs.enum != rhs.enum { return false }
    if lhs.ref != rhs.ref { return false }
    if lhs.id != rhs.id { return false }

    // Draft 2020-12
    if lhs.prefixItems != rhs.prefixItems { return false }
    if lhs.dependentSchemas != rhs.dependentSchemas { return false }
    if lhs.dependentRequired != rhs.dependentRequired { return false }
    if lhs.minContains != rhs.minContains { return false }
    if lhs.maxContains != rhs.maxContains { return false }
    if lhs.defs != rhs.defs { return false }
    if lhs.unevaluatedProperties != rhs.unevaluatedProperties { return false }
    if lhs.unevaluatedItems != rhs.unevaluatedItems { return false }
    if lhs.dynamicAnchor != rhs.dynamicAnchor { return false }
    if lhs.dynamicRef != rhs.dynamicRef { return false }
    if lhs.resolvedBaseURI != rhs.resolvedBaseURI { return false }
 
    return true
  }
}

// MARK: - Helper Codable Enums for Raw Formats

private enum RawType: Codable, Sendable {
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

  func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    switch self {
    case .single(let str):
      try container.encode(str)
    case .array(let strs):
      try container.encode(strs)
    }
  }
}

private enum RawItems: Codable, Sendable {
  case single(JSONSchema)
  case array([JSONSchema])

  init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    if let singleSchema = try? container.decode(JSONSchema.self) {
      self = .single(singleSchema)
    } else if let arraySchemas = try? container.decode([JSONSchema].self) {
      self = .array(arraySchemas)
    } else {
      throw DecodingError.dataCorruptedError(
        in: container,
        debugDescription: "Invalid items value: expected schema or array of schemas"
      )
    }
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    switch self {
    case .single(let schema):
      try container.encode(schema)
    case .array(let schemas):
      try container.encode(schemas)
    }
  }
}

private enum RawAdditionalProperties: Codable, Sendable {
  case boolean(Bool)
  case schema(JSONSchema)

  init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    if let boolVal = try? container.decode(Bool.self) {
      self = .boolean(boolVal)
    } else if let schemaVal = try? container.decode(JSONSchema.self) {
      self = .schema(schemaVal)
    } else {
      throw DecodingError.dataCorruptedError(
        in: container,
        debugDescription: "Invalid additionalProperties: expected boolean or schema"
      )
    }
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    switch self {
    case .boolean(let val):
      try container.encode(val)
    case .schema(let schema):
      try container.encode(schema)
    }
  }
}

// MARK: - Validation Implementation

extension JSONSchema {
  public func validate(instance: JSONValue) throws -> ValidationOutput {
    try validate(instance: instance, visitingSchemas: [], rootSchema: self, dynamicScope: [self])
  }

  private func validate(
    instance: JSONValue,
    visitingSchemas: Set<String>,
    rootSchema: JSONSchema,
    dynamicScope: [JSONSchema]
  ) throws -> ValidationOutput {
    if isBooleanSchema == true {
      if booleanSchemaValue == true {
        return ValidationOutput(instance: instance, schema: self)
      } else {
        throw ValidationError(path: "/", message: "Boolean schema 'false' rejects all values")
      }
    }

    var applicatorOutputs: [ValidationOutput] = []

    let resolvedRef = self.ref
    let resolvedLocalSchema = self.localSchema
    let resolvedDynamicRef = self.dynamicRef

    var targetSchema = resolvedLocalSchema?.value
    var actualRef = resolvedRef

    // Find the absolute root schema of the document
    var docRoot = rootSchema
    var curr: JSONSchema = self
    while let p = curr.parent {
      curr = p
    }
    docRoot = curr

    if let dRef = resolvedDynamicRef {
      actualRef = dRef
      let anchorName = dRef.replacingOccurrences(of: "#", with: "")
      
      // Walk dynamic scope forwards to find matching dynamicAnchor (outer-most first)
      for schema in dynamicScope {
        if let matched = schema.findSchema(byAnchor: anchorName) {
          targetSchema = matched
          break
        }
      }
      
      // Fallback to searching the document by anchor or pointer
      if targetSchema == nil {
        if dRef.hasPrefix("#") {
          let cleanAnchor = dRef.replacingOccurrences(of: "#", with: "")
          targetSchema = docRoot.findSchema(byAnchor: cleanAnchor)
          if targetSchema == nil {
            targetSchema = docRoot.resolvePointer(dRef)
          }
        } else if let currentBase = self.resolvedBaseURI,
                  let refURL = URL(string: dRef, relativeTo: currentBase) {
          targetSchema = resolveAbsoluteURL(refURL, docRoot: docRoot)
        }
      }
    } else if targetSchema == nil, let ref = resolvedRef {
      if ref.hasPrefix("#") {
        let currentBase = self.resolvedBaseURI
        let targetBase = currentBase.flatMap { docRoot.findSchema(byURI: $0) } ?? docRoot

        if ref == "#" {
          targetSchema = targetBase
        } else if ref.hasPrefix("#/") {
          targetSchema = targetBase.resolvePointer(ref)
        } else {
          let cleanAnchor = ref.replacingOccurrences(of: "#", with: "")
          targetSchema = targetBase.findSchema(byAnchor: cleanAnchor)
        }
      } else if let currentBase = self.resolvedBaseURI,
                let refURL = URL(string: ref, relativeTo: currentBase) {
        targetSchema = resolveAbsoluteURL(refURL, docRoot: docRoot)
      }
    }

    if targetSchema != nil || actualRef != nil {
      let cycleKey = actualRef ?? uniqueRefIdentifier ?? ObjectIdentifier(self).debugDescription
      guard !visitingSchemas.contains(cycleKey) else {
        // Cycle detected in validation! Break the recursion safely by returning success.
        return ValidationOutput(instance: instance, schema: self, matchedSchemaIDs: [cycleKey])
      }

      if let targetSchema {
        var newVisiting = visitingSchemas
        newVisiting.insert(cycleKey)
        do {
          var newScope = dynamicScope
          newScope.append(self)
          let innerOutput = try targetSchema.validate(
            instance: instance,
            visitingSchemas: newVisiting,
            rootSchema: rootSchema,
            dynamicScope: newScope
          )
          let mergedIDs = (innerOutput.matchedSchemaIDs + [cycleKey])
            .reduce(into: [String]()) {
              if !$0.contains($1) { $0.append($1) }
            }
          let refOutput = ValidationOutput(
            instance: instance,
            schema: self,
            matchedSchemaIDs: mergedIDs,
            children: innerOutput.children,
            evaluatedProperties: innerOutput.evaluatedProperties,
            evaluatedItems: innerOutput.evaluatedItems
          )
          applicatorOutputs.append(refOutput)
        } catch let error as ValidationError {
          throw ValidationError(
            path: error.path,
            message: "[\(cycleKey)] \(error.message)"
          )
        }
      } else {
        applicatorOutputs.append(ValidationOutput(
          instance: instance,
          schema: self,
          matchedSchemaIDs: [cycleKey]
        ))
      }
    }

    try validateType(instance: instance)

    var children: [String: ValidationOutput] = [:]
    var localEvalProps = Set<String>()
    var localEvalItems = Set<Int>()

    switch instance {
    case .string(let str):
      try validateStringConstraints(str: str)
    case .number(let num):
      try validateNumberConstraints(num: num)
    case .array(let itemsList):
      try validateArrayConstraints(
        itemsList: itemsList,
        children: &children,
        localEvalItems: &localEvalItems,
        rootSchema: rootSchema,
        dynamicScope: dynamicScope
      )
    case .object(let dict):
      try validateObjectConstraints(
        dict: dict,
        visitingSchemas: visitingSchemas,
        children: &children,
        localEvalProps: &localEvalProps,
        rootSchema: rootSchema,
        dynamicScope: dynamicScope
      )
    default:
      break
    }

    if let const {
      guard instance == const else {
        throw ValidationError(path: "/", message: "Expected const value: \(const)")
      }
    }
    if let `enum` {
      guard `enum`.contains(instance) else {
        throw ValidationError(path: "/", message: "Value is not in enum")
      }
    }

    try validateAllOf(
      instance: instance,
      visitingSchemas: visitingSchemas,
      outputs: &applicatorOutputs,
      rootSchema: rootSchema,
      dynamicScope: dynamicScope
    )
    try validateAnyOf(
      instance: instance,
      visitingSchemas: visitingSchemas,
      outputs: &applicatorOutputs,
      rootSchema: rootSchema,
      dynamicScope: dynamicScope
    )
    try validateOneOf(
      instance: instance,
      visitingSchemas: visitingSchemas,
      outputs: &applicatorOutputs,
      rootSchema: rootSchema,
      dynamicScope: dynamicScope
    )
    try validateNot(instance: instance, visitingSchemas: visitingSchemas, rootSchema: rootSchema, dynamicScope: dynamicScope)
    try validateIfThenElse(
      instance: instance,
      visitingSchemas: visitingSchemas,
      outputs: &applicatorOutputs,
      rootSchema: rootSchema,
      dynamicScope: dynamicScope
    )

    let baseOutput = ValidationOutput(
      instance: instance,
      schema: self,
      matchedSchemaIDs: id.map { [$0] } ?? [],
      children: children,
      evaluatedProperties: localEvalProps,
      evaluatedItems: localEvalItems
    )

    var finalOutput = baseOutput
    if !applicatorOutputs.isEmpty {
      finalOutput = mergeValidationOutputs([baseOutput] + applicatorOutputs, instance: instance, schema: self)
    }

    // Validate unevaluatedItems
    if let unevaluatedItemsSchema = unevaluatedItems?.value, case .array(let itemsList) = instance {
      let allIndices = Set(0..<itemsList.count)
      let unevaluatedIndices = allIndices.subtracting(finalOutput.evaluatedItems)
      
      var unevaluatedChildren: [String: ValidationOutput] = [:]
      var newEvalItems = finalOutput.evaluatedItems
      
      for index in unevaluatedIndices.sorted() {
        let item = itemsList[index]
        if unevaluatedItemsSchema.isBooleanSchema == true && unevaluatedItemsSchema.booleanSchemaValue == false {
          throw ValidationError(path: "/\(index)", message: "unevaluated item at index \(index) is not allowed by schema false")
        }
        
        do {
          var childScope = dynamicScope
          childScope.append(self)
          let childOutput = try unevaluatedItemsSchema.validate(
            instance: item,
            visitingSchemas: [],
            rootSchema: rootSchema,
            dynamicScope: childScope
          )
          unevaluatedChildren[String(index)] = childOutput
          newEvalItems.insert(index)
        } catch let error as ValidationError {
          let segment = String(index)
          let prependedPath = error.path == "/" ? "/\(segment)" : "/\(segment)\(error.path)"
          throw ValidationError(path: prependedPath, message: error.message)
        }
      }
      
      if !unevaluatedChildren.isEmpty {
        var mergedChildren = finalOutput.children
        for (k, v) in unevaluatedChildren {
          mergedChildren[k] = v
        }
        finalOutput = ValidationOutput(
          instance: finalOutput.instance,
          schema: finalOutput.schema,
          matchedSchemaIDs: finalOutput.matchedSchemaIDs,
          children: mergedChildren,
          evaluatedProperties: finalOutput.evaluatedProperties,
          evaluatedItems: newEvalItems
        )
      }
    }

    // Validate unevaluatedProperties
    if let unevaluatedPropsSchema = unevaluatedProperties?.value, case .object(let dict) = instance {
      let allKeys = Set(dict.keys)
      let unevaluatedKeys = allKeys.subtracting(finalOutput.evaluatedProperties)
      
      var unevaluatedChildren: [String: ValidationOutput] = [:]
      var newEvalProps = finalOutput.evaluatedProperties
      
      for key in unevaluatedKeys.sorted() {
        let val = dict[key]!
        if unevaluatedPropsSchema.isBooleanSchema == true && unevaluatedPropsSchema.booleanSchemaValue == false {
          throw ValidationError(path: "/\(key)", message: "unevaluated property '\(key)' is not allowed by schema false")
        }
        
        do {
          var childScope = dynamicScope
          childScope.append(self)
          let childOutput = try unevaluatedPropsSchema.validate(
            instance: val,
            visitingSchemas: [],
            rootSchema: rootSchema,
            dynamicScope: childScope
          )
          unevaluatedChildren[key] = childOutput
          newEvalProps.insert(key)
        } catch let error as ValidationError {
          let prependedPath = error.path == "/" ? "/\(key)" : "/\(key)\(error.path)"
          throw ValidationError(path: prependedPath, message: error.message)
        }
      }
      
      if !unevaluatedChildren.isEmpty {
        var mergedChildren = finalOutput.children
        for (k, v) in unevaluatedChildren {
          mergedChildren[k] = v
        }
        finalOutput = ValidationOutput(
          instance: finalOutput.instance,
          schema: finalOutput.schema,
          matchedSchemaIDs: finalOutput.matchedSchemaIDs,
          children: mergedChildren,
          evaluatedProperties: newEvalProps,
          evaluatedItems: finalOutput.evaluatedItems
        )
      }
    }

    return finalOutput
  }

  private func validateAllOf(
    instance: JSONValue,
    visitingSchemas: Set<String>,
    outputs: inout [ValidationOutput],
    rootSchema: JSONSchema,
    dynamicScope: [JSONSchema]
  ) throws {
    guard let allOf else { return }
    for subschema in allOf {
      var childScope = dynamicScope
      childScope.append(self)
      let output = try subschema.validate(
        instance: instance,
        visitingSchemas: visitingSchemas,
        rootSchema: rootSchema,
        dynamicScope: childScope
      )
      outputs.append(output)
    }
  }

  private func validateAnyOf(
    instance: JSONValue,
    visitingSchemas: Set<String>,
    outputs: inout [ValidationOutput],
    rootSchema: JSONSchema,
    dynamicScope: [JSONSchema]
  ) throws {
    guard let anyOf else { return }
    var matchedOutputs: [ValidationOutput] = []
    var errors: [ValidationError] = []
    for subschema in anyOf {
      do {
        var childScope = dynamicScope
        childScope.append(self)
        let output = try subschema.validate(
          instance: instance,
          visitingSchemas: visitingSchemas,
          rootSchema: rootSchema,
          dynamicScope: childScope
        )
        matchedOutputs.append(output)
      } catch let error as ValidationError {
        errors.append(error)
      } catch {
        errors.append(ValidationError(path: "/", message: String(describing: error)))
      }
    }
    guard !matchedOutputs.isEmpty else {
      let depst = errors.map { ($0, $0.path.split(separator: "/").count) }
      if let maxDepth = depst.map({ $1 }).max() {
        let deepestErrors = depst.filter { $1 == maxDepth }.map { $0.0 }
        if deepestErrors.count == 1 {
          throw deepestErrors[0]
        } else {
          let combinedMessage = "Instance did not match any subschema in anyOf: ["
            + deepestErrors.map { $0.message }.joined(separator: ", ")
            + "]"
          throw ValidationError(path: deepestErrors[0].path, message: combinedMessage)
        }
      }
      throw ValidationError(path: "/", message: "Instance did not match any subschema in anyOf")
    }
    outputs.append(contentsOf: matchedOutputs)
  }

  private func validateOneOf(
    instance: JSONValue,
    visitingSchemas: Set<String>,
    outputs: inout [ValidationOutput],
    rootSchema: JSONSchema,
    dynamicScope: [JSONSchema]
  ) throws {
    guard let oneOf else { return }
    var matchedCount = 0
    var matchedOutput: ValidationOutput? = nil
    var errors: [ValidationError] = []

    for subschema in oneOf {
      do {
        var childScope = dynamicScope
        childScope.append(self)
        let output = try subschema.validate(
          instance: instance,
          visitingSchemas: visitingSchemas,
          rootSchema: rootSchema,
          dynamicScope: childScope
        )
        matchedCount += 1
        if matchedCount > 1 {
          break
        }
        matchedOutput = output
      } catch let error as ValidationError {
        errors.append(error)
      } catch {
        errors.append(ValidationError(path: "/", message: String(describing: error)))
      }
    }

    if matchedCount > 1 {
      throw ValidationError(
        path: "/",
        message: "Instance matched multiple subschemas in oneOf, expected exactly 1 (early abort)"
      )
    }

    if let matchedOutput {
      outputs.append(matchedOutput)
    } else {
      if errors.isEmpty {
        throw ValidationError(path: "/", message: "Instance did not match any subschema in oneOf")
      }
      let depst = errors.map { ($0, $0.path.split(separator: "/").count) }
      if let maxDepth = depst.map({ $1 }).max() {
        let deepestErrors = depst.filter { $1 == maxDepth }.map { $0.0 }
        if deepestErrors.count == 1 {
          throw deepestErrors[0]
        } else {
          let firstPath = deepestErrors[0].path
          let allPathsEqual = deepestErrors.allSatisfy { $0.path == firstPath }
          let combinedMessage = "Instance did not match any subschema in oneOf: ["
            + deepestErrors.map { $0.message }.joined(separator: ", ")
            + "]"
          if allPathsEqual {
            throw ValidationError(path: firstPath, message: combinedMessage)
          } else {
            throw ValidationError(path: "/", message: combinedMessage)
          }
        }
      }
      throw ValidationError(path: "/", message: "Instance did not match any subschema in oneOf")
    }
  }

  private func validateNot(
    instance: JSONValue,
    visitingSchemas: Set<String>,
    rootSchema: JSONSchema,
    dynamicScope: [JSONSchema]
  ) throws {
    guard let notSchema = not?.value else { return }
    do {
      var childScope = dynamicScope
      childScope.append(self)
      _ = try notSchema.validate(
        instance: instance,
        visitingSchemas: visitingSchemas,
        rootSchema: rootSchema,
        dynamicScope: childScope
      )
    } catch {
      return
    }
    throw ValidationError(path: "/", message: "Instance matched schema but 'not' was specified")
  }

  private func validateIfThenElse(
    instance: JSONValue,
    visitingSchemas: Set<String>,
    outputs: inout [ValidationOutput],
    rootSchema: JSONSchema,
    dynamicScope: [JSONSchema]
  ) throws {
    guard let ifSchema = `if`?.value else { return }
    var ifSucceeded = false
    var ifOutput: ValidationOutput? = nil
    do {
      var childScope = dynamicScope
      childScope.append(self)
      ifOutput = try ifSchema.validate(
        instance: instance,
        visitingSchemas: visitingSchemas,
        rootSchema: rootSchema,
        dynamicScope: childScope
      )
      ifSucceeded = true
    } catch {
      // ifSchema failed
    }

    if ifSucceeded {
      if let thenSchema = then?.value {
        var childScope = dynamicScope
        childScope.append(self)
        let thenOutput = try thenSchema.validate(
          instance: instance,
          visitingSchemas: visitingSchemas,
          rootSchema: rootSchema,
          dynamicScope: childScope
        )
        if let ifOutput {
          let merged = mergeValidationOutputs([ifOutput, thenOutput], instance: instance, schema: self)
          outputs.append(merged)
        } else {
          outputs.append(thenOutput)
        }
      } else if let ifOutput {
        outputs.append(ifOutput)
      }
    } else {
      if let elseSchema = `else`?.value {
        var childScope = dynamicScope
        childScope.append(self)
        let elseOutput = try elseSchema.validate(
          instance: instance,
          visitingSchemas: visitingSchemas,
          rootSchema: rootSchema,
          dynamicScope: childScope
        )
        outputs.append(elseOutput)
      }
    }
  }


  private func validateType(instance: JSONValue) throws {
    guard let types, !omitType else { return }
    let matchedType = types.contains { type in
      switch type {
      case .string: if case .string = instance { return true }
      case .number: if case .number = instance { return true }
      case .integer:
        if case .number(let num) = instance {
          return num == floor(num)
        }
      case .boolean: if case .boolean = instance { return true }
      case .null: if case .null = instance { return true }
      case .object: if case .object = instance { return true }
      case .array: if case .array = instance { return true }
      }
      return false
    }
    if !matchedType {
      throw ValidationError(
        path: "/",
        message: "Expected type from \(types.map { $0.rawValue }.sorted()), got \(instance.typeName)"
      )
    }
  }

  private func validateStringConstraints(str: String) throws {
    if let minLength {
      guard str.count >= minLength else {
        throw ValidationError(path: "/", message: "String is too short")
      }
    }
    if let maxLength {
      guard str.count <= maxLength else {
        throw ValidationError(path: "/", message: "String is too long")
      }
    }
    if let regex {
      let range = NSRange(str.startIndex..<str.endIndex, in: str)
      guard regex.firstMatch(in: str, options: [], range: range) != nil else {
        throw ValidationError(path: "/", message: "String does not match pattern")
      }
    }
  }

  private func validateNumberConstraints(num: Double) throws {
    if let minimum {
      guard num >= minimum else {
        throw ValidationError(path: "/", message: "Number is too small")
      }
    }
    if let maximum {
      guard num <= maximum else {
        throw ValidationError(path: "/", message: "Number is too large")
      }
    }
    if let exclusiveMinimum {
      guard num > exclusiveMinimum else {
        throw ValidationError(path: "/", message: "Number must be strictly greater than \(exclusiveMinimum)")
      }
    }
    if let exclusiveMaximum {
      guard num < exclusiveMaximum else {
        throw ValidationError(path: "/", message: "Number must be strictly less than \(exclusiveMaximum)")
      }
    }
    if let multipleOf {
      let remainder = num.truncatingRemainder(dividingBy: multipleOf)
      guard abs(remainder) < 0.000001 || abs(remainder - multipleOf) < 0.000001 else {
        throw ValidationError(path: "/", message: "Number must be a multiple of \(multipleOf)")
      }
    }
  }

  private func validateArrayConstraints(
    itemsList: [JSONValue],
    children: inout [String: ValidationOutput],
    localEvalItems: inout Set<Int>,
    rootSchema: JSONSchema,
    dynamicScope: [JSONSchema]
  ) throws {
    if let minItems {
      guard itemsList.count >= minItems else {
        throw ValidationError(path: "/", message: "Array has too few items")
      }
    }
    if let maxItems {
      guard itemsList.count <= maxItems else {
        throw ValidationError(path: "/", message: "Array has too many items")
      }
    }
    if let uniqueItems, uniqueItems {
      for i in 0..<itemsList.count {
        for j in (i + 1)..<itemsList.count {
          if itemsList[i] == itemsList[j] {
            throw ValidationError(
              path: "/",
              message: "Array contains duplicate items at indices \(i) and \(j)"
            )
          }
        }
      }
    }

    let prefixSchemas = prefixItems ?? itemArray
    if let prefixSchemas {
      for (index, item) in itemsList.enumerated() {
        if index < prefixSchemas.count {
          do {
            var childScope = dynamicScope
            childScope.append(self)
            let childOutput = try prefixSchemas[index].validate(
              instance: item,
              visitingSchemas: [],
              rootSchema: rootSchema,
              dynamicScope: childScope
            )
            children[String(index)] = childOutput
            localEvalItems.insert(index)
          } catch let error as ValidationError {
            let segment = String(index)
            let prependedPath = error.path == "/" ? "/\(segment)" : "/\(segment)\(error.path)"
            throw ValidationError(path: prependedPath, message: error.message)
          }
        } else if let itemsSchema = items?.value {
          do {
            var childScope = dynamicScope
            childScope.append(self)
            let childOutput = try itemsSchema.validate(
              instance: item,
              visitingSchemas: [],
              rootSchema: rootSchema,
              dynamicScope: childScope
            )
            children[String(index)] = childOutput
            localEvalItems.insert(index)
          } catch let error as ValidationError {
            let segment = String(index)
            let prependedPath = error.path == "/" ? "/\(segment)" : "/\(segment)\(error.path)"
            throw ValidationError(path: prependedPath, message: error.message)
          }
        }
      }
    } else if let itemsSchema = items?.value {
      for (index, item) in itemsList.enumerated() {
        do {
          var childScope = dynamicScope
          childScope.append(self)
          let childOutput = try itemsSchema.validate(
            instance: item,
            visitingSchemas: [],
            rootSchema: rootSchema,
            dynamicScope: childScope
          )
          children[String(index)] = childOutput
          localEvalItems.insert(index)
        } catch let error as ValidationError {
          let segment = String(index)
          let prependedPath = error.path == "/" ? "/\(segment)" : "/\(segment)\(error.path)"
          throw ValidationError(path: prependedPath, message: error.message)
        }
      }
    }
 
    if let contains {
      var matchCount = 0
      var containsChildren: [String: ValidationOutput] = [:]
      for (index, item) in itemsList.enumerated() {
        var childScope = dynamicScope
        childScope.append(self)
        if let output = try? contains.value.validate(
          instance: item,
          visitingSchemas: [],
          rootSchema: rootSchema,
          dynamicScope: childScope
        ) {
          matchCount += 1
          containsChildren[String(index)] = output
          localEvalItems.insert(index)
        }
      }
      
      let minC = minContains ?? 1
      guard matchCount >= minC else {
        throw ValidationError(
          path: "/",
          message: "Array contains only \(matchCount) element(s) matching the 'contains' schema, expected at least \(minC)"
        )
      }
      
      if let maxC = maxContains {
        guard matchCount <= maxC else {
          throw ValidationError(
            path: "/",
            message: "Array contains \(matchCount) element(s) matching the 'contains' schema, expected at most \(maxC)"
          )
        }
      }
      
      for (key, val) in containsChildren {
        children[key] = val
      }
    }
  }

  private func validateObjectConstraints(
    dict: [String: JSONValue],
    visitingSchemas: Set<String>,
    children: inout [String: ValidationOutput],
    localEvalProps: inout Set<String>,
    rootSchema: JSONSchema,
    dynamicScope: [JSONSchema]
  ) throws {
    if let minProperties {
      guard dict.count >= minProperties else {
        throw ValidationError(path: "/", message: "Object has too few properties")
      }
    }
    if let maxProperties {
      guard dict.count <= maxProperties else {
        throw ValidationError(path: "/", message: "Object has too many properties")
      }
    }

    if let required {
      for reqKey in required {
        guard dict[reqKey] != nil else {
          throw ValidationError(path: "/", message: "missing required property: \(reqKey)")
        }
      }
    }

    for (key, val) in dict {
      var matchedAnyPattern = false
      var patternOutputs: [ValidationOutput] = []

      if let patternProperties {
        for (pattern, patternSchema) in patternProperties {
          if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
            let range = NSRange(key.startIndex..<key.endIndex, in: key)
            if regex.firstMatch(in: key, options: [], range: range) != nil {
              matchedAnyPattern = true
              do {
                var childScope = dynamicScope
                childScope.append(self)
                let out = try patternSchema.validate(
                  instance: val,
                  visitingSchemas: [],
                  rootSchema: rootSchema,
                  dynamicScope: childScope
                )
                patternOutputs.append(out)
                localEvalProps.insert(key)
              } catch let error as ValidationError {
                let prependedPath = error.path == "/" ? "/\(key)" : "/\(key)\(error.path)"
                throw ValidationError(path: prependedPath, message: error.message)
              }
            }
          }
        }
      }
 
      var standardOutput: ValidationOutput? = nil
      if let propertySchema = properties?[key] {
        do {
          var childScope = dynamicScope
          childScope.append(self)
          standardOutput = try propertySchema.validate(
            instance: val,
            visitingSchemas: [],
            rootSchema: rootSchema,
            dynamicScope: childScope
          )
          localEvalProps.insert(key)
        } catch let error as ValidationError {
          let prependedPath = error.path == "/" ? "/\(key)" : "/\(key)\(error.path)"
          throw ValidationError(path: prependedPath, message: error.message)
        }
      }
 
      var additionalOutput: ValidationOutput? = nil
      let isDeclaredProperty = properties?[key] != nil
      if !isDeclaredProperty && !matchedAnyPattern {
        if let additionalPropertiesSchema = additionalProperties?.value {
          if additionalPropertiesSchema.isBooleanSchema == true && additionalPropertiesSchema.booleanSchemaValue == false {
            throw ValidationError(path: "/\(key)", message: "additional property '\(key)' is not allowed")
          }
          do {
            var childScope = dynamicScope
            childScope.append(self)
            additionalOutput = try additionalPropertiesSchema.validate(
              instance: val,
              visitingSchemas: [],
              rootSchema: rootSchema,
              dynamicScope: childScope
            )
            localEvalProps.insert(key)
          } catch let error as ValidationError {
            let prependedPath = error.path == "/" ? "/\(key)" : "/\(key)\(error.path)"
            throw ValidationError(path: prependedPath, message: error.message)
          }
        }
      }

      var keyOutputs: [ValidationOutput] = []
      if let standardOutput {
        keyOutputs.append(standardOutput)
      }
      keyOutputs.append(contentsOf: patternOutputs)
      if let additionalOutput {
        keyOutputs.append(additionalOutput)
      }

      if !keyOutputs.isEmpty {
        children[key] = mergeValidationOutputs(keyOutputs, instance: val, schema: self)
      }
    }

    if let propertyNamesSchema = propertyNames?.value {
      for key in dict.keys {
        let keyInstance = JSONValue.string(key)
        do {
          var childScope = dynamicScope
          childScope.append(self)
          _ = try propertyNamesSchema.validate(
            instance: keyInstance,
            visitingSchemas: [],
            rootSchema: rootSchema,
            dynamicScope: childScope
          )
        } catch let error as ValidationError {
          let prependedPath = error.path == "/" ? "/\(key)" : "/\(key)\(error.path)"
          throw ValidationError(
            path: prependedPath,
            message: "Property name '\(key)' is invalid: \(error.message)"
          )
        }
      }
    }

    if let dependencies {
      var dependencyOutputs: [ValidationOutput] = []
      for (triggerKey, dependency) in dependencies {
        if dict.keys.contains(triggerKey) {
          switch dependency {
          case .property(let requiredKeys):
            for reqKey in requiredKeys {
              if !dict.keys.contains(reqKey) {
                throw ValidationError(
                  path: "/",
                  message: "Dependency requirement not met: trigger key '\(triggerKey)' requires '\(reqKey)'"
                )
               }
             }
          case .schema(let depSchema):
            var childScope = dynamicScope
            childScope.append(self)
            let output = try depSchema.validate(
              instance: JSONValue.object(dict),
              visitingSchemas: visitingSchemas,
              rootSchema: rootSchema,
              dynamicScope: childScope
            )
            dependencyOutputs.append(output)
            localEvalProps.formUnion(output.evaluatedProperties)
          }
        }
      }
      if !dependencyOutputs.isEmpty {
        let merged = mergeValidationOutputs(dependencyOutputs, instance: JSONValue.object(dict), schema: self)
        for (k, v) in merged.children {
          children[k] = v
        }
      }
    }

    // Draft 2020-12
    if let dependentRequired {
      for (triggerKey, requiredKeys) in dependentRequired {
        if dict.keys.contains(triggerKey) {
          for reqKey in requiredKeys {
            if !dict.keys.contains(reqKey) {
              throw ValidationError(
                path: "/",
                message: "Dependent requirement not met: trigger key '\(triggerKey)' requires '\(reqKey)'"
              )
            }
          }
        }
      }
    }

    if let dependentSchemas {
      var depOutputs: [ValidationOutput] = []
      for (triggerKey, depSchema) in dependentSchemas {
        if dict.keys.contains(triggerKey) {
          var childScope = dynamicScope
          childScope.append(self)
          let out = try depSchema.validate(
            instance: JSONValue.object(dict),
            visitingSchemas: visitingSchemas,
            rootSchema: rootSchema,
            dynamicScope: childScope
          )
          depOutputs.append(out)
          localEvalProps.formUnion(out.evaluatedProperties)
        }
      }
      if !depOutputs.isEmpty {
        let merged = mergeValidationOutputs(depOutputs, instance: JSONValue.object(dict), schema: self)
        for (k, v) in merged.children {
          children[k] = v
        }
      }
    }
  }
}

// MARK: - DSL Modifiers and Statics

extension JSONSchema {
  public static func string() -> JSONSchema { JSONSchema(types: [.string]) }
  public static func integer() -> JSONSchema { JSONSchema(types: [.integer]) }
  public static func number() -> JSONSchema { JSONSchema(types: [.number]) }
  public static func boolean() -> JSONSchema { JSONSchema(types: [.boolean]) }
  public static func null() -> JSONSchema { JSONSchema(types: [.null]) }
  
  public static func types(_ set: Set<JSONSchemaType>) -> JSONSchema { JSONSchema(types: set) }
  
  public static func object(
    omitType: Bool = false,
    additionalProperties: JSONSchema? = nil,
    @JSONSchemaPropertyBuilder _ propertiesBuilder: () -> [JSONSchemaProperty] = { [] }
  ) -> JSONSchema {
    let props = propertiesBuilder()
    var propDict: [String: JSONSchema] = [:]
    var reqSet = Set<String>()
    for prop in props {
      propDict[prop.name] = prop.schema
      if prop.isRequired {
        reqSet.insert(prop.name)
      }
    }
    return JSONSchema(
      types: omitType ? nil : [.object],
      properties: propDict,
      omitType: omitType,
      required: reqSet.isEmpty ? nil : reqSet,
      additionalProperties: additionalProperties.map { Box($0) }
    )
  }

  public static func array(
    @JSONSchemaArrayBuilder _ itemsBuilder: () -> [JSONSchema] = { [] }
  ) -> JSONSchema {
    let subschemas = itemsBuilder()
    if subschemas.count == 1 {
      return JSONSchema(types: [.array], items: Box(subschemas[0]), itemArray: nil)
    } else {
      return JSONSchema(types: [.array], items: nil, itemArray: subschemas)
    }
  }

  public static func stub(
    uri: String,
    @JSONSchemaPropertyBuilder _ propertiesBuilder: () -> [JSONSchemaProperty] = { [] }
  ) -> JSONSchema {
    let props = propertiesBuilder()
    var propDict: [String: JSONSchema] = [:]
    var reqSet = Set<String>()
    for prop in props {
      propDict[prop.name] = prop.schema
      if prop.isRequired {
        reqSet.insert(prop.name)
      }
    }
    return JSONSchema(
      types: [.object],
      properties: propDict,
      required: reqSet.isEmpty ? nil : reqSet,
      id: uri
    )
  }

  public static func stub(uri: String, localSchema: JSONSchema) -> JSONSchema {
    return JSONSchema(
      types: localSchema.types,
      properties: localSchema.properties,
      items: localSchema.items,
      itemArray: localSchema.itemArray,
      omitType: localSchema.omitType,
      minimum: localSchema.minimum,
      maximum: localSchema.maximum,
      exclusiveMinimum: localSchema.exclusiveMinimum,
      exclusiveMaximum: localSchema.exclusiveMaximum,
      multipleOf: localSchema.multipleOf,
      minLength: localSchema.minLength,
      maxLength: localSchema.maxLength,
      pattern: localSchema.pattern,
      minItems: localSchema.minItems,
      maxItems: localSchema.maxItems,
      uniqueItems: localSchema.uniqueItems,
      contains: localSchema.contains,
      minProperties: localSchema.minProperties,
      maxProperties: localSchema.maxProperties,
      required: localSchema.required,
      additionalProperties: localSchema.additionalProperties,
      patternProperties: localSchema.patternProperties,
      propertyNames: localSchema.propertyNames,
      dependencies: localSchema.dependencies,
      allOf: localSchema.allOf,
      anyOf: localSchema.anyOf,
      oneOf: localSchema.oneOf,
      not: localSchema.not,
      if: localSchema.if,
      then: localSchema.then,
      else: localSchema.else,
      const: localSchema.const,
      enum: localSchema.enum,
      ref: localSchema.ref,
      id: uri,
      isBooleanSchema: localSchema.isBooleanSchema,
      booleanSchemaValue: localSchema.booleanSchemaValue,
      prefixItems: localSchema.prefixItems,
      dependentSchemas: localSchema.dependentSchemas,
      dependentRequired: localSchema.dependentRequired,
      minContains: localSchema.minContains,
      maxContains: localSchema.maxContains,
      defs: localSchema.defs,
      unevaluatedProperties: localSchema.unevaluatedProperties,
      unevaluatedItems: localSchema.unevaluatedItems,
      dynamicAnchor: localSchema.dynamicAnchor,
      dynamicRef: localSchema.dynamicRef
    )
  }

  public static func stub(
    uri: String,
    localSchema: @escaping @Sendable () -> JSONSchema
  ) -> JSONSchema {
    return JSONSchema(
      ref: nil,
      id: uri,
      localSchemaGetter: localSchema
    )
  }


  public static func reference(_ stub: @escaping @autoclosure @Sendable () -> JSONSchema) -> JSONSchema {
    return JSONSchema(
      ref: nil,
      id: nil,
      uniqueRefIdentifier: UUID().uuidString,
      localSchemaGetter: stub
    )
  }

  // String Modifiers
  public func minLength(_ limit: Int) -> JSONSchema {
    mutatingCopy(minLength: limit)
  }
  
  public func maxLength(_ limit: Int) -> JSONSchema {
    mutatingCopy(maxLength: limit)
  }
  
  public func pattern(_ pattern: String) -> JSONSchema {
    mutatingCopy(pattern: pattern)
  }

  // Numeric Modifiers (Double)
  public func minimum(_ limit: Double) -> JSONSchema {
    mutatingCopy(minimum: limit)
  }

  public func maximum(_ limit: Double) -> JSONSchema {
    mutatingCopy(maximum: limit)
  }

  public func multipleOf(_ divisor: Double) -> JSONSchema {
    mutatingCopy(multipleOf: divisor)
  }

  // Numeric Modifiers (Int Conveniences)
  public func minimum(_ limit: Int) -> JSONSchema {
    mutatingCopy(minimum: Double(limit))
  }

  public func maximum(_ limit: Int) -> JSONSchema {
    mutatingCopy(maximum: Double(limit))
  }

  public func multipleOf(_ divisor: Int) -> JSONSchema {
    mutatingCopy(multipleOf: Double(divisor))
  }

  // Array Modifiers
  public func minItems(_ limit: Int) -> JSONSchema {
    mutatingCopy(minItems: limit)
  }

  public func maxItems(_ limit: Int) -> JSONSchema {
    mutatingCopy(maxItems: limit)
  }

  public func uniqueItems(_ unique: Bool) -> JSONSchema {
    mutatingCopy(uniqueItems: unique)
  }

  // Universal Modifiers
  public func const(_ value: JSONValue) -> JSONSchema {
    mutatingCopy(const: value)
  }

  public func `enum`(_ values: [JSONValue]) -> JSONSchema {
    mutatingCopy(enum: values)
  }

  public func dependencies(_ dependencies: [String: Dependency]) -> JSONSchema {
    mutatingCopy(dependencies: dependencies)
  }

  public func patternProperties(_ patternProperties: [String: JSONSchema]) -> JSONSchema {
    mutatingCopy(patternProperties: patternProperties)
  }


  internal func mutatingCopy(
    minimum: Double? = nil,
    maximum: Double? = nil,
    exclusiveMinimum: Double? = nil,
    exclusiveMaximum: Double? = nil,
    multipleOf: Double? = nil,
    minLength: Int? = nil,
    maxLength: Int? = nil,
    pattern: String? = nil,
    minItems: Int? = nil,
    maxItems: Int? = nil,
    uniqueItems: Bool? = nil,
    contains: JSONSchema? = nil,
    minProperties: Int? = nil,
    maxProperties: Int? = nil,
    required: Set<String>? = nil,
    additionalProperties: JSONSchema? = nil,
    patternProperties: [String: JSONSchema]? = nil,
    propertyNames: JSONSchema? = nil,
    dependencies: [String: Dependency]? = nil,
    allOf: [JSONSchema]? = nil,
    anyOf: [JSONSchema]? = nil,
    oneOf: [JSONSchema]? = nil,
    not: JSONSchema? = nil,
    `if`: JSONSchema? = nil,
    `then`: JSONSchema? = nil,
    `else`: JSONSchema? = nil,
    const: JSONValue? = nil,
    `enum` enumValues: [JSONValue]? = nil,
    ref: String? = nil,
    id: String? = nil,
    localSchema: Box<JSONSchema>? = nil,
    localSchemaGetter: (@Sendable () -> JSONSchema)? = nil,
    // Draft 2020-12
    prefixItems: [JSONSchema]? = nil,
    dependentSchemas: [String: JSONSchema]? = nil,
    dependentRequired: [String: Set<String>]? = nil,
    minContains: Int? = nil,
    maxContains: Int? = nil,
    defs: [String: JSONSchema]? = nil,
    unevaluatedProperties: JSONSchema? = nil,
    unevaluatedItems: JSONSchema? = nil,
    dynamicAnchor: String? = nil,
    dynamicRef: String? = nil
  ) -> JSONSchema {
    return JSONSchema(
      types: self.types,
      properties: self.properties,
      items: self.items,
      itemArray: self.itemArray,
      omitType: self.omitType,
      minimum: minimum ?? self.minimum,
      maximum: maximum ?? self.maximum,
      exclusiveMinimum: exclusiveMinimum ?? self.exclusiveMinimum,
      exclusiveMaximum: exclusiveMaximum ?? self.exclusiveMaximum,
      multipleOf: multipleOf ?? self.multipleOf,
      minLength: minLength ?? self.minLength,
      maxLength: maxLength ?? self.maxLength,
      pattern: pattern ?? self.pattern,
      minItems: minItems ?? self.minItems,
      maxItems: maxItems ?? self.maxItems,
      uniqueItems: uniqueItems ?? self.uniqueItems,
      contains: contains.map { Box($0) } ?? self.contains,
      minProperties: minProperties ?? self.minProperties,
      maxProperties: maxProperties ?? self.maxProperties,
      required: required ?? self.required,
      additionalProperties: additionalProperties.map { Box($0) } ?? self.additionalProperties,
      patternProperties: patternProperties ?? self.patternProperties,
      propertyNames: propertyNames.map { Box($0) } ?? self.propertyNames,
      dependencies: dependencies ?? self.dependencies,
      allOf: allOf ?? self.allOf,
      anyOf: anyOf ?? self.anyOf,
      oneOf: oneOf ?? self.oneOf,
      not: not.map { Box($0) } ?? self.not,
      if: `if`.map { Box($0) } ?? self.if,
      then: `then`.map { Box($0) } ?? self.then,
      else: `else`.map { Box($0) } ?? self.else,
      const: const ?? self.const,
      enum: enumValues ?? self.enum,
      ref: ref ?? self.ref,
      id: id ?? self.id,
      localSchema: localSchema,
      localSchemaGetter: localSchemaGetter ?? self.localSchemaGetter,
      isBooleanSchema: self.isBooleanSchema,
      booleanSchemaValue: self.booleanSchemaValue,
      // Draft 2020-12
      prefixItems: prefixItems ?? self.prefixItems,
      dependentSchemas: dependentSchemas ?? self.dependentSchemas,
      dependentRequired: dependentRequired ?? self.dependentRequired,
      minContains: minContains ?? self.minContains,
      maxContains: maxContains ?? self.maxContains,
      defs: defs ?? self.defs,
      unevaluatedProperties: unevaluatedProperties.map { Box($0) } ?? self.unevaluatedProperties,
      unevaluatedItems: unevaluatedItems.map { Box($0) } ?? self.unevaluatedItems,
      dynamicAnchor: dynamicAnchor ?? self.dynamicAnchor,
      dynamicRef: dynamicRef ?? self.dynamicRef
    )
  }
}

// MARK: - JSON Pointer Resolver

extension JSONSchema {
  public func resolvePointer(_ pointer: String) -> JSONSchema? {
    if pointer == "#" || pointer == "" { return self }
    guard pointer.hasPrefix("#/") else { return nil }
    let path = pointer.dropFirst(2).split(separator: "/").map { String($0) }
    return resolvePath(path)
  }

  private func unescapedToken(_ token: String) -> String {
    token
      .replacingOccurrences(of: "~1", with: "/")
      .replacingOccurrences(of: "~0", with: "~")
  }

  private func resolvePath(_ path: [String]) -> JSONSchema? {
    guard !path.isEmpty else { return self }
    
    let token = unescapedToken(path[0])
    let remaining = Array(path.dropFirst())
    
    if token == "$defs" || token == "definitions" {
      guard path.count > 1 else { return nil }
      let key = unescapedToken(path[1])
      if let defs = self.defs, let sub = defs[key] {
        return sub.resolvePath(Array(path.dropFirst(2)))
      }
      return nil
    }
    
    if token == "properties" {
      guard path.count > 1 else { return nil }
      let key = unescapedToken(path[1])
      if let propSchema = self.properties?[key] {
        return propSchema.resolvePath(Array(path.dropFirst(2)))
      }
      return nil
    }
    
    if token == "patternProperties" {
      guard path.count > 1 else { return nil }
      let key = unescapedToken(path[1])
      if let patternSchema = self.patternProperties?[key] {
        return patternSchema.resolvePath(Array(path.dropFirst(2)))
      }
      return nil
    }

    if token == "dependentSchemas" {
      guard path.count > 1 else { return nil }
      let key = unescapedToken(path[1])
      if let depSchema = self.dependentSchemas?[key] {
        return depSchema.resolvePath(Array(path.dropFirst(2)))
      }
      return nil
    }

    if token == "prefixItems" {
      guard path.count > 1, let idx = Int(path[1]) else { return nil }
      if let prefixItems, idx >= 0, idx < prefixItems.count {
        return prefixItems[idx].resolvePath(Array(path.dropFirst(2)))
      }
      return nil
    }

    if token == "items" {
      if let items = self.items?.value {
        return items.resolvePath(remaining)
      } else if let itemArray = self.itemArray {
        guard path.count > 1, let idx = Int(path[1]) else { return nil }
        if idx >= 0, idx < itemArray.count {
          return itemArray[idx].resolvePath(Array(path.dropFirst(2)))
        }
      }
      return nil
    }
    
    if token == "contains", let contains = self.contains?.value {
      return contains.resolvePath(remaining)
    }

    if token == "propertyNames", let propertyNames = self.propertyNames?.value {
      return propertyNames.resolvePath(remaining)
    }

    if token == "additionalProperties", let additionalProperties = self.additionalProperties?.value {
      return additionalProperties.resolvePath(remaining)
    }

    if token == "allOf" {
      guard path.count > 1, let idx = Int(path[1]) else { return nil }
      if let allOf, idx >= 0, idx < allOf.count {
        return allOf[idx].resolvePath(Array(path.dropFirst(2)))
      }
      return nil
    }
    if token == "anyOf" {
      guard path.count > 1, let idx = Int(path[1]) else { return nil }
      if let anyOf, idx >= 0, idx < anyOf.count {
        return anyOf[idx].resolvePath(Array(path.dropFirst(2)))
      }
      return nil
    }
    if token == "oneOf" {
      guard path.count > 1, let idx = Int(path[1]) else { return nil }
      if let oneOf, idx >= 0, idx < oneOf.count {
        return oneOf[idx].resolvePath(Array(path.dropFirst(2)))
      }
      return nil
    }
    if token == "not", let not = self.not?.value {
      return not.resolvePath(remaining)
    }
    if token == "if", let `if` = self.if?.value {
      return `if`.resolvePath(remaining)
    }
    if token == "then", let then = self.then?.value {
      return then.resolvePath(remaining)
    }
    if token == "else", let `else` = self.else?.value {
      return `else`.resolvePath(remaining)
    }
    
    if let defs = self.defs, let sub = defs[token] {
      return sub.resolvePath(remaining)
    }

    return nil
  }
}

// MARK: - Lexical Scope Resolver

extension JSONSchema {
  public func resolveLexicalScopes(parentBaseURI: URL? = nil, parentSchema: JSONSchema? = nil) {
    self.parent = parentSchema
    let currentBaseURI: URL?
    if let idString = self.id, let idURL = URL(string: idString, relativeTo: parentBaseURI) {
      currentBaseURI = idURL
    } else {
      currentBaseURI = parentBaseURI
    }
    self.resolvedBaseURI = currentBaseURI
    
    // Recursively resolve child properties
    properties?.values.forEach { $0.resolveLexicalScopes(parentBaseURI: currentBaseURI, parentSchema: self) }
    patternProperties?.values.forEach { $0.resolveLexicalScopes(parentBaseURI: currentBaseURI, parentSchema: self) }
    prefixItems?.forEach { $0.resolveLexicalScopes(parentBaseURI: currentBaseURI, parentSchema: self) }
    items?.value.resolveLexicalScopes(parentBaseURI: currentBaseURI, parentSchema: self)
    itemArray?.forEach { $0.resolveLexicalScopes(parentBaseURI: currentBaseURI, parentSchema: self) }
    defs?.values.forEach { $0.resolveLexicalScopes(parentBaseURI: currentBaseURI, parentSchema: self) }
    allOf?.forEach { $0.resolveLexicalScopes(parentBaseURI: currentBaseURI, parentSchema: self) }
    anyOf?.forEach { $0.resolveLexicalScopes(parentBaseURI: currentBaseURI, parentSchema: self) }
    oneOf?.forEach { $0.resolveLexicalScopes(parentBaseURI: currentBaseURI, parentSchema: self) }
    not?.value.resolveLexicalScopes(parentBaseURI: currentBaseURI, parentSchema: self)
    `if`?.value.resolveLexicalScopes(parentBaseURI: currentBaseURI, parentSchema: self)
    then?.value.resolveLexicalScopes(parentBaseURI: currentBaseURI, parentSchema: self)
    `else`?.value.resolveLexicalScopes(parentBaseURI: currentBaseURI, parentSchema: self)
    unevaluatedProperties?.value.resolveLexicalScopes(parentBaseURI: currentBaseURI, parentSchema: self)
    unevaluatedItems?.value.resolveLexicalScopes(parentBaseURI: currentBaseURI, parentSchema: self)
    dependentSchemas?.values.forEach { $0.resolveLexicalScopes(parentBaseURI: currentBaseURI, parentSchema: self) }
  }

  public func findSchema(byURI targetURI: URL) -> JSONSchema? {
    if let base = self.resolvedBaseURI, base == targetURI {
      return self
    }
    if let idStr = self.id, let idURL = URL(string: idStr), idURL == targetURI {
      return self
    }
    
    if let found = properties?.values.compactMap({ $0.findSchema(byURI: targetURI) }).first { return found }
    if let found = patternProperties?.values.compactMap({ $0.findSchema(byURI: targetURI) }).first { return found }
    if let found = prefixItems?.compactMap({ $0.findSchema(byURI: targetURI) }).first { return found }
    if let found = items?.value.findSchema(byURI: targetURI) { return found }
    if let found = itemArray?.compactMap({ $0.findSchema(byURI: targetURI) }).first { return found }
    if let found = defs?.values.compactMap({ $0.findSchema(byURI: targetURI) }).first { return found }
    if let found = allOf?.compactMap({ $0.findSchema(byURI: targetURI) }).first { return found }
    if let found = anyOf?.compactMap({ $0.findSchema(byURI: targetURI) }).first { return found }
    if let found = oneOf?.compactMap({ $0.findSchema(byURI: targetURI) }).first { return found }
    if let found = not?.value.findSchema(byURI: targetURI) { return found }
    if let found = `if`?.value.findSchema(byURI: targetURI) { return found }
    if let found = then?.value.findSchema(byURI: targetURI) { return found }
    if let found = `else`?.value.findSchema(byURI: targetURI) { return found }
    if let found = unevaluatedProperties?.value.findSchema(byURI: targetURI) { return found }
    if let found = unevaluatedItems?.value.findSchema(byURI: targetURI) { return found }
    if let found = dependentSchemas?.values.compactMap({ $0.findSchema(byURI: targetURI) }).first { return found }
    
    return nil
  }

  public func findSchema(byAnchor anchorName: String) -> JSONSchema? {
    if self.dynamicAnchor == anchorName {
      return self
    }
    
    if let found = properties?.values.compactMap({ $0.findSchema(byAnchor: anchorName) }).first { return found }
    if let found = patternProperties?.values.compactMap({ $0.findSchema(byAnchor: anchorName) }).first { return found }
    if let found = prefixItems?.compactMap({ $0.findSchema(byAnchor: anchorName) }).first { return found }
    if let found = items?.value.findSchema(byAnchor: anchorName) { return found }
    if let found = itemArray?.compactMap({ $0.findSchema(byAnchor: anchorName) }).first { return found }
    if let found = defs?.values.compactMap({ $0.findSchema(byAnchor: anchorName) }).first { return found }
    if let found = allOf?.compactMap({ $0.findSchema(byAnchor: anchorName) }).first { return found }
    if let found = anyOf?.compactMap({ $0.findSchema(byAnchor: anchorName) }).first { return found }
    if let found = oneOf?.compactMap({ $0.findSchema(byAnchor: anchorName) }).first { return found }
    if let found = not?.value.findSchema(byAnchor: anchorName) { return found }
    if let found = `if`?.value.findSchema(byAnchor: anchorName) { return found }
    if let found = then?.value.findSchema(byAnchor: anchorName) { return found }
    if let found = `else`?.value.findSchema(byAnchor: anchorName) { return found }
    if let found = unevaluatedProperties?.value.findSchema(byAnchor: anchorName) { return found }
    if let found = unevaluatedItems?.value.findSchema(byAnchor: anchorName) { return found }
    if let found = dependentSchemas?.values.compactMap({ $0.findSchema(byAnchor: anchorName) }).first { return found }
    
    return nil
  }

  public func resolveAbsoluteURL(_ url: URL, docRoot: JSONSchema) -> JSONSchema? {
    var components = URLComponents(url: url, resolvingAgainstBaseURL: true)
    let fragment = components?.fragment
    components?.fragment = nil
    guard let cleanURL = components?.url else { return nil }
    
    guard let targetBase = docRoot.findSchema(byURI: cleanURL) else { return nil }
    
    if let fragment = fragment, !fragment.isEmpty {
      if fragment.hasPrefix("/") {
        return targetBase.resolvePointer("#" + fragment)
      } else {
        return targetBase.findSchema(byAnchor: fragment)
      }
    }
    return targetBase
  }
}

