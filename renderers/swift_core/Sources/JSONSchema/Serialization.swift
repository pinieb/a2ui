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

public enum SerializationSorting {
  case none
  case alphabetical
}

extension JSONSchema {
  /// Bundles and serializes the schema to a JSON string.
  public func print(
    bundleExternalRefs: Bool = true,
    sorting: SerializationSorting = .none,
    prettyPrinted: Bool = false
  ) throws -> String {
    let encoder = JSONEncoder()
    if prettyPrinted {
      encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    } else {
      encoder.outputFormatting = [.sortedKeys]
    }

    if !bundleExternalRefs {
      let data = try encoder.encode(self)
      let rawString = String(decoding: data, as: UTF8.self)
      if sorting == .alphabetical {
        return try sortJSONKeysAlphabetically(rawString, prettyPrinted: prettyPrinted)
      }
      return rawString
    }

    // Bundle references
    let tracker = ReferenceTracker()
    let transformed = try tracker.transformAndRegister(self)

    let topLevel = TopLevelSchema(
      defs: tracker.definitions.isEmpty ? nil : tracker.definitions,
      schema: transformed
    )
    let data = try encoder.encode(topLevel)
    let rawString = String(decoding: data, as: UTF8.self)
    if sorting == .alphabetical {
      return try sortJSONKeysAlphabetically(rawString, prettyPrinted: prettyPrinted)
    }
    return rawString
  }
}

// MARK: - ReferenceTracker

private final class ReferenceTracker {
  private(set) var definitions: [String: JSONSchema] = [:]
  private var uriToName: [String: String] = [:]
  private var visiting: Set<String> = []

  func transformAndRegister(_ schema: JSONSchema) throws -> JSONSchema {
    if let ref = schema.ref {
      let name = try registerReference(uri: ref, schema: schema)
      return JSONSchema(ref: "#/$defs/\(name)", id: nil)
    }

    // Recursively transform children
    var newProperties: [String: JSONSchema]? = nil
    if let properties = schema.properties {
      var temp: [String: JSONSchema] = [:]
      for key in properties.keys.sorted() {
        if let v = properties[key] {
          temp[key] = try transformAndRegister(v)
        }
      }
      newProperties = temp
    }

    let newItems = try schema.items.map { Box(try transformAndRegister($0.value)) }
    let newItemArray = try schema.itemArray?.map { try transformAndRegister($0) }
    let newContains = try schema.contains.map { Box(try transformAndRegister($0.value)) }
    let newAdditionalProperties = try schema.additionalProperties.map {
      Box(try transformAndRegister($0.value))
    }

    var newPatternProperties: [String: JSONSchema]? = nil
    if let patternProperties = schema.patternProperties {
      var temp: [String: JSONSchema] = [:]
      for key in patternProperties.keys.sorted() {
        if let v = patternProperties[key] {
          temp[key] = try transformAndRegister(v)
        }
      }
      newPatternProperties = temp
    }

    let newPropertyNames = try schema.propertyNames.map { Box(try transformAndRegister($0.value)) }

    var newDependencies: [String: Dependency]? = nil
    if let dependencies = schema.dependencies {
      var temp: [String: Dependency] = [:]
      for key in dependencies.keys.sorted() {
        if let v = dependencies[key] {
          switch v {
          case .property(let keys):
            temp[key] = .property(keys)
          case .schema(let s):
            temp[key] = .schema(try transformAndRegister(s))
          }
        }
      }
      newDependencies = temp
    }

    let newAllOf = try schema.allOf?.map { try transformAndRegister($0) }
    let newAnyOf = try schema.anyOf?.map { try transformAndRegister($0) }
    let newOneOf = try schema.oneOf?.map { try transformAndRegister($0) }
    let newNot = try schema.not.map { Box(try transformAndRegister($0.value)) }
    let newIf = try schema.if.map { Box(try transformAndRegister($0.value)) }
    let newThen = try schema.then.map { Box(try transformAndRegister($0.value)) }
    let newElse = try schema.else.map { Box(try transformAndRegister($0.value)) }

    return JSONSchema(
      types: schema.types,
      properties: newProperties,
      items: newItems,
      itemArray: newItemArray,
      omitType: schema.omitType,
      minimum: schema.minimum,
      maximum: schema.maximum,
      exclusiveMinimum: schema.exclusiveMinimum,
      exclusiveMaximum: schema.exclusiveMaximum,
      multipleOf: schema.multipleOf,
      minLength: schema.minLength,
      maxLength: schema.maxLength,
      pattern: schema.pattern,
      minItems: schema.minItems,
      maxItems: schema.maxItems,
      uniqueItems: schema.uniqueItems,
      contains: newContains,
      minProperties: schema.minProperties,
      maxProperties: schema.maxProperties,
      required: schema.required,
      additionalProperties: newAdditionalProperties,
      patternProperties: newPatternProperties,
      propertyNames: newPropertyNames,
      dependencies: newDependencies,
      allOf: newAllOf,
      anyOf: newAnyOf,
      oneOf: newOneOf,
      not: newNot,
      if: newIf,
      then: newThen,
      else: newElse,
      const: schema.const,
      enum: schema.enum,
      ref: schema.ref,
      id: schema.id,
      isBooleanSchema: schema.isBooleanSchema,
      booleanSchemaValue: schema.booleanSchemaValue
    )
  }

  private func registerReference(uri: String, schema: JSONSchema) throws -> String {
    if let existingName = uriToName[uri] {
      return existingName
    }

    // Extract base name from URI
    let baseName: String
    if let url = URL(string: uri) {
      let lastComponent = url.lastPathComponent
      if lastComponent.hasSuffix(".json") {
        baseName = String(lastComponent.dropSuffix(".json"))
      } else {
        baseName = lastComponent.isEmpty ? "ref" : lastComponent
      }
    } else {
      baseName = "ref"
    }

    var candidate = baseName
    var counter = 1
    while definitions[candidate] != nil {
      candidate = "\(baseName)\(counter)"
      counter += 1
    }

    uriToName[uri] = candidate

    // Detect cycle!
    guard !visiting.contains(uri) else {
      // Register an empty stub for now to break recursion, it will be populated
      // when the parent call unwinds.
      definitions[candidate] = JSONSchema(ref: nil, id: uri)
      return candidate
    }

    visiting.insert(uri)
    defer { visiting.remove(uri) }

    var targetSchema = schema
    var visited = Set<String>()
    while let next = targetSchema.localSchema?.value {
      if let ref = targetSchema.ref {
        if visited.contains(ref) { break }
        visited.insert(ref)
      }
      targetSchema = next
    }
    let schemaWithoutRef = JSONSchema(
      types: targetSchema.types,
      properties: targetSchema.properties,
      items: targetSchema.items,
      itemArray: targetSchema.itemArray,
      omitType: targetSchema.omitType,
      minimum: targetSchema.minimum,
      maximum: targetSchema.maximum,
      exclusiveMinimum: targetSchema.exclusiveMinimum,
      exclusiveMaximum: targetSchema.exclusiveMaximum,
      multipleOf: targetSchema.multipleOf,
      minLength: targetSchema.minLength,
      maxLength: targetSchema.maxLength,
      pattern: targetSchema.pattern,
      minItems: targetSchema.minItems,
      maxItems: targetSchema.maxItems,
      uniqueItems: targetSchema.uniqueItems,
      contains: targetSchema.contains,
      minProperties: targetSchema.minProperties,
      maxProperties: targetSchema.maxProperties,
      required: targetSchema.required,
      additionalProperties: targetSchema.additionalProperties,
      patternProperties: targetSchema.patternProperties,
      propertyNames: targetSchema.propertyNames,
      dependencies: targetSchema.dependencies,
      allOf: targetSchema.allOf,
      anyOf: targetSchema.anyOf,
      oneOf: targetSchema.oneOf,
      not: targetSchema.not,
      if: targetSchema.if,
      then: targetSchema.then,
      else: targetSchema.else,
      const: targetSchema.const,
      enum: targetSchema.enum,
      ref: nil,
      id: uri,
      isBooleanSchema: targetSchema.isBooleanSchema,
      booleanSchemaValue: targetSchema.booleanSchemaValue
    )

    let transformedSchema = try transformAndRegister(schemaWithoutRef)
    definitions[candidate] = transformedSchema

    return candidate
  }
}

extension String {
  fileprivate func dropSuffix(_ suffix: String) -> Substring {
    if hasSuffix(suffix) {
      return prefix(count - suffix.count)
    }
    return self[...]
  }
}

// MARK: - Helper JSON Sorting & Conversion

private func convertToJSONValue(_ val: Any) throws -> JSONValue {
  if let str = val as? String {
    return .string(str)
  } else if let num = val as? Double {
    return .number(num)
  } else if let num = val as? Int {
    return .number(Double(num))
  } else if let bool = val as? Bool {
    return .boolean(bool)
  } else if let arr = val as? [Any] {
    return .array(try arr.map { try convertToJSONValue($0) })
  } else if let dict = val as? [String: Any] {
    var mapped: [String: JSONValue] = [:]
    for (k, v) in dict {
      mapped[k] = try convertToJSONValue(v)
    }
    return .object(mapped)
  } else {
    return .null
  }
}

private func sortJSONKeysAlphabetically(_ jsonString: String, prettyPrinted: Bool) throws -> String
{
  let data = Data(jsonString.utf8)
  let obj = try JSONSerialization.jsonObject(with: data, options: [])

  let options: JSONSerialization.WritingOptions =
    prettyPrinted ? [.prettyPrinted, .sortedKeys] : [.sortedKeys]
  let sortedData = try JSONSerialization.data(withJSONObject: obj, options: options)
  let result = String(decoding: sortedData, as: UTF8.self)
  return result.replacingOccurrences(of: "\\/", with: "/")
}

// MARK: - Custom Coding Keys for Dynamic Serialization

struct DynamicCodingKeys: CodingKey {
  var stringValue: String
  init?(stringValue: String) {
    self.stringValue = stringValue
  }
  var intValue: Int?
  init?(intValue: Int) {
    return nil
  }
}

// MARK: - TopLevelSchema Wrapper for Bundling

private struct TopLevelSchema: Encodable {
  let defs: [String: JSONSchema]?
  let schema: JSONSchema

  enum CodingKeys: String, CodingKey {
    case defs = "$defs"
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    if let defs {
      // Sort defs alphabetically to ensure deterministic serialization
      let sortedDefs = defs.sorted(by: { $0.key < $1.key })
      var defsContainer = container.nestedContainer(keyedBy: DynamicCodingKeys.self, forKey: .defs)
      for (key, val) in sortedDefs {
        if let codingKey = DynamicCodingKeys(stringValue: key) {
          try defsContainer.encode(val, forKey: codingKey)
        }
      }
    }
    try schema.encode(to: encoder)
  }
}
