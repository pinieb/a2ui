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

import A2UIJSON
import Foundation
import Testing

struct ParserTests {

  @Test
  func `Parser decodes primitives and objects`() throws {
    let jsonString = """
      {
        "type": "object",
        "properties": {
          "name": {
            "type": "string"
          }
        }
      }
      """
    let schema = try JSONSchema.parse(jsonString)
    #expect(schema.types == [.object])
    let nameProp = try #require(schema.properties?["name"])
    #expect(nameProp.types == [.string])
  }

  @Test
  func `Parser decodes anyOf and allOf schemas`() throws {
    let anyOfJson = """
      {
        "anyOf": [
          {"type": "string"},
          {"type": "integer"}
        ]
      }
      """
    let anyOfSchema = try JSONSchema.parse(anyOfJson)
    let anyOf = try #require(anyOfSchema.anyOf)
    #expect(anyOf.count == 2)
    #expect(anyOf[0].types == [.string])
    #expect(anyOf[1].types == [.integer])

    let allOfJson = """
      {
        "allOf": [
          {
            "type": "object",
            "properties": {
              "name": {"type": "string"}
            }
          },
          {
            "type": "object",
            "properties": {
              "age": {"type": "integer"}
            }
          }
        ]
      }
      """
    let allOfSchema = try JSONSchema.parse(allOfJson)
    let allOf = try #require(allOfSchema.allOf)
    #expect(allOf.count == 2)
    #expect(allOf[0].properties?["name"]?.types == [.string])
    #expect(allOf[1].properties?["age"]?.types == [.integer])
  }

  @Test
  func `Validation successfully annotates matched schema IDs`() throws {
    let stub = JSONSchema.stub(
      uri: "https://a2ui.dev/schema/v1/component.json"
    )
    let schema = JSONSchema.object {
      JSONSchemaProperty.property("component") { JSONSchema.reference(stub) }
    }
    let instance = JSONValue.object([
      "component": .object([:])
    ])
    let output = try schema.validate(instance: instance)

    #expect(output.matchedSchemaIDs.isEmpty)
    let child = try #require(output.children["component"])
    #expect(child.instance == .object([:]))
  }

  @Test
  func `Validation throws detailed errors on type mismatch`() throws {
    let schema = JSONSchema.integer()
    let instance = JSONValue.string("hello")

    do {
      _ = try schema.validate(instance: instance)
      Issue.record("Expected validation to fail with ValidationError")
    } catch let error as ValidationError {
      #expect(error.path == "/")
      #expect(error.message.contains("integer"))
      #expect(error.message.contains("string"))
    } catch {
      Issue.record("Expected ValidationError, but got: \(error)")
    }
  }

  @Test
  func `Validation throws detailed errors on missing properties`() throws {
    let schema = JSONSchema.object {
      JSONSchemaProperty.property("id", isRequired: true) { JSONSchema.string() }
    }
    let instance = JSONValue.object([:])

    do {
      _ = try schema.validate(instance: instance)
      Issue.record("Expected validation to fail with ValidationError")
    } catch let error as ValidationError {
      #expect(error.path == "/")
      #expect(error.message.contains("missing"))
      #expect(error.message.contains("id"))
    } catch {
      Issue.record("Expected ValidationError, but got: \(error)")
    }
  }

  @Test
  func `Validation enforces local schema in ExternalSchemaStub`() throws {
    let localSchema = JSONSchema.string()
    let stub = JSONSchema.stub(
      uri: "https://a2ui.dev/schema/v1/component.json",
      localSchema: localSchema
    )
    let schema = JSONSchema.object {
      JSONSchemaProperty.property("component") { stub }
    }
    let instance = JSONValue.object(["component": .number(123)])

    do {
      _ = try schema.validate(instance: instance)
      Issue.record("Expected validation to fail with ValidationError")
    } catch let error as ValidationError {
      #expect(error.path == "/component")
      #expect(error.message.contains("string"))
      #expect(error.message.contains("number"))
    } catch {
      Issue.record("Expected ValidationError, but got: \(error)")
    }
  }

  @Test
  func `ExternalSchemaStub can be initialized with SchemaBuilder`() throws {
    let stub = JSONSchema.stub(
      uri: "https://a2ui.dev/schema/v1/component.json",
      {
        JSONSchemaProperty.property("id", isRequired: true) { JSONSchema.string() }
        JSONSchemaProperty.property("label") { JSONSchema.string() }
      }
    )

    let instance = JSONValue.object([
      "id": .string("comp123"),
      "label": .string("Click Me"),
    ])
    let output = try stub.validate(instance: instance)

    #expect(output.children["id"] != nil)
    #expect(output.children["label"] != nil)
  }

  @Test
  func `Validation rejects additional properties when forbidden`() throws {
    let schema = JSONSchema.object(additionalProperties: JSONSchema(booleanSchema: false)) {
      JSONSchemaProperty.property("path", isRequired: true) { JSONSchema.string() }
    }

    let printed = try schema.print(
      bundleExternalRefs: false,
      sorting: SerializationSorting.alphabetical,
      prettyPrinted: false
    )
    #expect(printed.contains("\"additionalProperties\":false"))

    let instance = JSONValue.object([
      "path": .string("/a"),
      "extra": .number(123),
    ])
    do {
      _ = try schema.validate(instance: instance)
      Issue.record("Expected validation to fail with ValidationError")
    } catch let error as ValidationError {
      #expect(error.path == "/extra")
      #expect(error.message.contains("additional"))
    } catch {
      Issue.record("Expected ValidationError, but got: \(error)")
    }
  }

  @Test
  func `Parser decodes boolean schemas`() throws {
    let trueSchema = try JSONSchema.parse("true")
    #expect(trueSchema.isBooleanSchema == true)
    #expect(trueSchema.booleanSchemaValue == true)
    let trueOutput = try trueSchema.validate(instance: .string("any-value"))
    #expect(trueOutput.instance == .string("any-value"))

    let falseSchema = try JSONSchema.parse("false")
    #expect(falseSchema.isBooleanSchema == true)
    #expect(falseSchema.booleanSchemaValue == false)
    #expect(throws: ValidationError.self) {
      try falseSchema.validate(instance: .string("any-value"))
    }
  }

  @Test
  func `Parser decodes array with optional items`() throws {
    let arrayJson = """
      {
        "type": "array"
      }
      """
    let schema = try JSONSchema.parse(arrayJson)
    #expect(schema.types == [.array])

    // And validates successfully
    let output = try schema.validate(instance: .array([.string("any"), .number(123)]))
    #expect(output.instance == .array([.string("any"), .number(123)]))
  }

  @Test
  func `Validators ignore non-applicable types`() throws {
    // 1. Implicit schemas (omitType = true) ignore non-applicable types
    let implicitObjectSchema = JSONSchema.object(omitType: true) {
      JSONSchemaProperty.property("name") { JSONSchema.string() }
    }
    let stringInstance = JSONValue.string("not-an-object")
    let implicitObjectOutput = try implicitObjectSchema.validate(instance: stringInstance)
    #expect(implicitObjectOutput.instance == stringInstance)

    let implicitArraySchema = JSONSchema(types: [.array], items: Box(JSONSchema.string()), omitType: true)
    let implicitArrayOutput = try implicitArraySchema.validate(instance: stringInstance)
    #expect(implicitArrayOutput.instance == stringInstance)

    // 2. Explicit schemas (omitType = false) enforce type constraints
    let explicitObjectSchema = JSONSchema.object(omitType: false) {
      JSONSchemaProperty.property("name") { JSONSchema.string() }
    }
    #expect(throws: ValidationError.self) {
      try explicitObjectSchema.validate(instance: stringInstance)
    }

    let explicitArraySchema = JSONSchema(types: [.array], items: Box(JSONSchema.string()), omitType: false)
    #expect(throws: ValidationError.self) {
      try explicitArraySchema.validate(instance: stringInstance)
    }
  }

  @Test
  func `Parser decodes const and enum, and validates them`() throws {
    // 1. Const schema
    let constJson = """
      {
        "const": {"name": "Alice", "age": 30}
      }
      """
    let constSchema = try JSONSchema.parse(constJson)
    let alice = JSONValue.object(["name": .string("Alice"), "age": .number(30)])
    let bob = JSONValue.object(["name": .string("Bob"), "age": .number(25)])

    let outputConst = try constSchema.validate(instance: alice)
    #expect(outputConst.instance == alice)

    #expect(throws: ValidationError.self) {
      try constSchema.validate(instance: bob)
    }

    // 2. Enum schema
    let enumJson = """
      {
        "enum": ["red", "green", "blue"]
      }
      """
    let enumSchema = try JSONSchema.parse(enumJson)
    let outputEnum = try enumSchema.validate(instance: .string("green"))
    #expect(outputEnum.instance == .string("green"))

    #expect(throws: ValidationError.self) {
      try enumSchema.validate(instance: .string("yellow"))
    }
  }

  @Test
  func `Parser decodes uniqueItems and validates deep array uniqueness`() throws {
    let uniqueJson = """
      {
        "type": "array",
        "uniqueItems": true
      }
      """
    let schema = try JSONSchema.parse(uniqueJson)

    // Distinct items
    let distinctInstance = JSONValue.array([
      .number(1),
      .number(2),
      .array([.string("a")]),
      .array([.string("b")])
    ])
    _ = try schema.validate(instance: distinctInstance)

    // Duplicate items (deep check)
    let duplicateInstance = JSONValue.array([
      .number(1),
      .array([.string("a")]),
      .number(2),
      .array([.string("a")])
    ])
    #expect(throws: ValidationError.self) {
      try schema.validate(instance: duplicateInstance)
    }
  }

  @Test
  func `Parser decodes additionalProperties schema and validates it`() throws {
    let additionalSchemaJson = """
      {
        "type": "object",
        "properties": {
          "name": { "type": "string" }
        },
        "additionalProperties": { "type": "integer" }
      }
      """
    let schema = try JSONSchema.parse(additionalSchemaJson)

    // Valid instance: additional property is an integer
    let validInstance = JSONValue.object([
      "name": .string("Alice"),
      "age": .number(30)
    ])
    _ = try schema.validate(instance: validInstance)

    // Invalid instance: additional property is a string
    let invalidInstance = JSONValue.object([
      "name": .string("Alice"),
      "role": .string("admin")
    ])
    #expect(throws: ValidationError.self) {
      try schema.validate(instance: invalidInstance)
    }
  }

  @Test
  func `Parser decodes oneOf schema and validates it`() throws {
    let oneOfJson = """
      {
        "oneOf": [
          {"type": "integer"},
          {"type": "number"}
        ]
      }
      """
    let schema = try JSONSchema.parse(oneOfJson)
    #expect(schema.oneOf != nil)

    // A decimal matches only number (exactly 1) -> valid
    let decimalVal = JSONValue.number(1.5)
    _ = try schema.validate(instance: decimalVal)

    // An integer matches both integer AND number (2 matches) -> invalid
    let intVal = JSONValue.number(5.0)
    #expect(throws: ValidationError.self) {
      try schema.validate(instance: intVal)
    }

    // A string matches neither (0 matches) -> invalid
    let stringVal = JSONValue.string("hello")
    #expect(throws: ValidationError.self) {
      try schema.validate(instance: stringVal)
    }
  }

  @Test
  func `Parser decodes not schema and validates it`() throws {
    let notJson = """
      {
        "not": {"type": "string"}
      }
      """
    let schema = try JSONSchema.parse(notJson)
    #expect(schema.not != nil)

    // An integer is not a string -> valid
    _ = try schema.validate(instance: .number(123))

    // A string is a string -> invalid
    #expect(throws: ValidationError.self) {
      try schema.validate(instance: .string("hello"))
    }
  }

  @Test
  func `Parser decodes patternProperties and validates them`() throws {
    let patternJson = """
      {
        "type": "object",
        "patternProperties": {
          "^f": {"type": "string"},
          "o$": {"type": "integer"}
        },
        "additionalProperties": false
      }
      """
    let schema = try JSONSchema.parse(patternJson)
    #expect(schema.patternProperties?.count == 2)

    // Valid:
    // "fiz" matches "^f" (string) -> valid
    // "baro" matches "o$" (integer) -> valid
    let validInstance = JSONValue.object([
      "fiz": .string("hello"),
      "baro": .number(123.0)
    ])
    _ = try schema.validate(instance: validInstance)

    // Invalid: "fiz" is not a string
    let invalidInstance1 = JSONValue.object([
      "fiz": .number(456.0)
    ])
    #expect(throws: ValidationError.self) {
      try schema.validate(instance: invalidInstance1)
    }

    // Invalid: "baro" is not an integer
    let invalidInstance2 = JSONValue.object([
      "baro": .string("not-int")
    ])
    #expect(throws: ValidationError.self) {
      try schema.validate(instance: invalidInstance2)
    }

    // Invalid: "baz" matches neither and additionalProperties is false
    let invalidInstance3 = JSONValue.object([
      "baz": .string("hello")
    ])
    #expect(throws: ValidationError.self) {
      try schema.validate(instance: invalidInstance3)
    }
  }

  @Test
  func `Parser decodes conditional if-then-else and validates it`() throws {
    let conditionalJson = """
      {
        "if": { "type": "integer" },
        "then": { "enum": [1, 2, 3] },
        "else": { "type": "string" }
      }
      """
    let schema = try JSONSchema.parse(conditionalJson)

    // Case 1: If matches (integer), and then matches (1) -> valid
    _ = try schema.validate(instance: .number(1))

    // Case 2: If matches (integer), but then does not match (5) -> invalid
    #expect(throws: ValidationError.self) {
      try schema.validate(instance: .number(5))
    }

    // Case 3: If does not match (not integer), but else matches (string) -> valid
    _ = try schema.validate(instance: .string("hello"))

    // Case 4: If does not match (not integer), and else does not match (boolean) -> invalid
    #expect(throws: ValidationError.self) {
      try schema.validate(instance: .boolean(true))
    }
  }

  @Test
  func `Parser decodes contains and validates it`() throws {
    let containsJson = """
      {
        "contains": { "type": "integer" }
      }
      """
    let schema = try JSONSchema.parse(containsJson)

    // Case 1: Array contains an integer -> valid
    _ = try schema.validate(instance: .array([.string("hello"), .number(5)]))

    // Case 2: Array does not contain an integer -> invalid
    #expect(throws: ValidationError.self) {
      try schema.validate(instance: .array([.string("hello"), .string("world")]))
    }

    // Case 3: Non-array instance -> valid
    _ = try schema.validate(instance: .string("not-an-array"))
  }

  @Test
  func `Parser decodes propertyNames and validates it`() throws {
    let propertyNamesJson = """
      {
        "propertyNames": { "enum": ["foo", "bar"] }
      }
      """
    let schema = try JSONSchema.parse(propertyNamesJson)

    // Case 1: Object has valid property names -> valid
    _ = try schema.validate(instance: .object(["foo": .number(1), "bar": .string("test")]))

    // Case 2: Object has an invalid property name -> invalid
    #expect(throws: ValidationError.self) {
      try schema.validate(instance: .object(["foo": .number(1), "baz": .string("test")]))
    }

    // Case 3: Non-object instance -> valid
    _ = try schema.validate(instance: .string("not-an-object"))
  }

  @Test
  func `Parser decodes dependencies and validates it`() throws {
    let dependenciesJson = """
      {
        "type": "object",
        "dependencies": {
          "a": ["b", "c"],
          "x": {
            "properties": {
              "y": { "type": "string" }
            },
            "required": ["y"]
          }
        }
      }
      """
    let schema = try JSONSchema.parse(dependenciesJson)

    // Case 1: Trigger 'a' is present, dependencies 'b' and 'c' are present -> valid
    _ = try schema.validate(instance: .object(["a": .number(1), "b": .number(2), "c": .number(3)]))

    // Case 2: Trigger 'a' is present, but 'c' is missing -> invalid
    #expect(throws: ValidationError.self) {
      try schema.validate(instance: .object(["a": .number(1), "b": .number(2)]))
    }

    // Case 3: Trigger 'x' is present, and schema dependency is met (y is present and a string) -> valid
    _ = try schema.validate(instance: .object(["x": .number(1), "y": .string("hello")]))

    // Case 4: Trigger 'x' is present, but schema dependency is not met (y is missing) -> invalid
    #expect(throws: ValidationError.self) {
      try schema.validate(instance: .object(["x": .number(1)]))
    }

    // Case 5: Trigger 'x' is present, but schema dependency is not met (y is not a string) -> invalid
    #expect(throws: ValidationError.self) {
      try schema.validate(instance: .object(["x": .number(1), "y": .number(123)]))
    }

    // Case 6: Neither trigger is present -> valid
    _ = try schema.validate(instance: .object(["b": .number(2), "z": .number(99)]))
  }

  @Test
  func testRecursiveSchemaDSL() throws {
    final class SchemaRefBox: @unchecked Sendable {
      var schema: JSONSchema!
    }

    let box = SchemaRefBox()
    let nodeSchema = JSONSchema.object {
      JSONSchemaProperty.property("value") { JSONSchema.integer() }
      JSONSchemaProperty.property("next") { JSONSchema.reference(box.schema) }
    }
    box.schema = nodeSchema

    // Case 1: Valid recursive list -> valid
    let validInstance = JSONValue.object([
      "value": .number(1),
      "next": .object([
        "value": .number(2),
        "next": .object([
          "value": .number(3)
        ])
      ])
    ])
    _ = try nodeSchema.validate(instance: validInstance)

    // Case 2: Invalid nested value in recursive list -> invalid
    let invalidInstance = JSONValue.object([
      "value": .number(1),
      "next": .object([
        "value": .number(2),
        "next": .object([
          "value": .string("not-an-integer")
        ])
      ])
    ])
    
    #expect(throws: ValidationError.self) {
      try nodeSchema.validate(instance: invalidInstance)
    }
  }

  @Test
  func testDraft202012ArrayPrefixItemsAndItems() throws {
    let schemaJson = """
      {
        "type": "array",
        "prefixItems": [
          {"type": "string"},
          {"type": "integer"}
        ],
        "items": {"type": "boolean"}
      }
      """
    let schema = try JSONSchema.parse(schemaJson)
    
    let valid = JSONValue.array([.string("hello"), .number(42), .boolean(true), .boolean(false)])
    _ = try schema.validate(instance: valid)
    
    let invalidUniform = JSONValue.array([.string("hello"), .number(42), .boolean(true), .string("invalid")])
    #expect(throws: ValidationError.self) {
      try schema.validate(instance: invalidUniform)
    }
    
    let invalidPrefix = JSONValue.array([.number(123), .number(42)])
    #expect(throws: ValidationError.self) {
      try schema.validate(instance: invalidPrefix)
    }
  }

  @Test
  func testDraft202012ArrayMinMaxContains() throws {
    let schemaJson = """
      {
        "type": "array",
        "contains": {"type": "integer"},
        "minContains": 2,
        "maxContains": 3
      }
      """
    let schema = try JSONSchema.parse(schemaJson)
    
    let valid2 = JSONValue.array([.string("a"), .number(1), .string("b"), .number(2)])
    _ = try schema.validate(instance: valid2)
    
    let valid3 = JSONValue.array([.number(1), .number(2), .number(3)])
    _ = try schema.validate(instance: valid3)
    
    let invalidTooFew = JSONValue.array([.number(1), .string("a"), .string("b")])
    #expect(throws: ValidationError.self) {
      try schema.validate(instance: invalidTooFew)
    }
    
    let invalidTooMany = JSONValue.array([.number(1), .number(2), .number(3), .number(4)])
    #expect(throws: ValidationError.self) {
      try schema.validate(instance: invalidTooMany)
    }
  }

  @Test
  func testDraft202012ObjectDependentRequiredAndDependentSchemas() throws {
    let schemaJson = """
      {
        "type": "object",
        "dependentRequired": {
          "credit_card": ["billing_address"]
        },
        "dependentSchemas": {
          "special_user": {
            "properties": {
              "clearance_level": {"type": "integer", "minimum": 5}
            },
            "required": ["clearance_level"]
          }
        }
      }
      """
    let schema = try JSONSchema.parse(schemaJson)
    
    let validRequired = JSONValue.object([
      "credit_card": .string("1234-5678"),
      "billing_address": .string("123 Main St")
    ])
    _ = try schema.validate(instance: validRequired)
    
    let invalidRequired = JSONValue.object([
      "credit_card": .string("1234-5678")
    ])
    #expect(throws: ValidationError.self) {
      try schema.validate(instance: invalidRequired)
    }
    
    let validSchema = JSONValue.object([
      "special_user": .boolean(true),
      "clearance_level": .number(6)
    ])
    _ = try schema.validate(instance: validSchema)
    
    let invalidSchemaValue = JSONValue.object([
      "special_user": .boolean(true),
      "clearance_level": .number(3)
    ])
    #expect(throws: ValidationError.self) {
      try schema.validate(instance: invalidSchemaValue)
    }
    
    let invalidSchemaMissing = JSONValue.object([
      "special_user": .boolean(true)
    ])
    #expect(throws: ValidationError.self) {
      try schema.validate(instance: invalidSchemaMissing)
    }
  }

  @Test
  func testDraft202012DynamicPointerResolving() throws {
    let schemaJson = """
      {
        "type": "object",
        "properties": {
          "user": { "$ref": "#/$defs/userSchema" }
        },
        "$defs": {
          "userSchema": {
            "type": "object",
            "properties": {
              "name": { "type": "string" },
              "friend": { "$ref": "#/$defs/userSchema" }
            },
            "required": ["name"]
          }
        }
      }
      """
    let schema = try JSONSchema.parse(schemaJson)
    
    let valid = JSONValue.object([
      "user": .object([
        "name": .string("Alice"),
        "friend": .object([
          "name": .string("Bob")
        ])
      ])
    ])
    _ = try schema.validate(instance: valid)
    
    let invalid = JSONValue.object([
      "user": .object([
        "name": .string("Alice"),
        "friend": .object([
          "friend_name": .string("Bob")
        ])
      ])
    ])
    #expect(throws: ValidationError.self) {
      try schema.validate(instance: invalid)
    }
  }

  @Test
  func testStrictUnicodeCodepointComparison() throws {
    let decomposed = "cafe\u{301}"
    let precomposed = "café"
    
    let valDecomposed = JSONValue.string(decomposed)
    let valPrecomposed = JSONValue.string(precomposed)
    
    #expect(valDecomposed != valPrecomposed)
  }

  @Test
  func testDiagnoseActionSchemaCrash() throws {
    let event = JSONValue.object([
      "event": .object([
        "name": .string("click"),
        "context": .object(["userID": .string("123")]),
      ])
    ])
    _ = try A2UICommonSchema.action.validate(instance: event)
  }

  @Test
  func testDraft202012DynamicReferencing() throws {
    let schemaJson = """
    {
      "$id": "https://example.com/root",
      "$defs": {
        "tree": {
          "$id": "https://example.com/tree",
          "$dynamicAnchor": "node",
          "type": "object",
          "properties": {
            "value": true,
            "children": {
              "type": "array",
              "items": { "$dynamicRef": "#node" }
            }
          }
        },
        "intTree": {
          "$id": "https://example.com/int-tree",
          "$dynamicAnchor": "node",
          "$ref": "https://example.com/tree",
          "properties": {
            "value": { "type": "integer" }
          }
        }
      }
    }
    """
    let rootSchema = try JSONSchema.parse(schemaJson)
    
    // Resolve the specialized integer-tree schema
    guard let intTreeSchema = rootSchema.resolvePointer("#/$defs/intTree") else {
      Issue.record("Failed to resolve intTree schema")
      return
    }
    
    // Valid instance (all values are integers)
    let validInstance = JSONValue.object([
      "value": .number(1),
      "children": .array([
        .object([
          "value": .number(2),
          "children": .array([])
        ])
      ])
    ])
    
    _ = try intTreeSchema.validate(instance: validInstance)
    
    // Invalid instance (child value is a string, which violates the specialized tree constraint)
    let invalidInstance = JSONValue.object([
      "value": .number(1),
      "children": .array([
        .object([
          "value": .string("not-an-integer"),
          "children": .array([])
        ])
      ])
    ])
    
    #expect(throws: ValidationError.self) {
      try intTreeSchema.validate(instance: invalidInstance)
    }
    
    // If we validate using the generic tree schema directly, it should pass because "value" can be anything
    guard let genericTreeSchema = rootSchema.resolvePointer("#/$defs/tree") else {
      Issue.record("Failed to resolve generic tree schema")
      return
    }
    _ = try genericTreeSchema.validate(instance: invalidInstance)
  }

  @Test
  func testDraft202012LexicalScoping() throws {
    let schemaJson = """
    {
      "$id": "https://example.com/root",
      "properties": {
        "sub": {
          "$id": "folder/",
          "properties": {
            "leaf": {
              "$id": "file.json",
              "type": "string"
            },
            "inherited": {
              "type": "integer"
            }
          }
        }
      }
    }
    """
    let schema = try JSONSchema.parse(schemaJson)
    
    #expect(schema.resolvedBaseURI?.absoluteString == "https://example.com/root")
    
    guard let subSchema = schema.properties?["sub"] else {
      Issue.record("Missing subSchema")
      return
    }
    #expect(subSchema.resolvedBaseURI?.absoluteString == "https://example.com/folder/")
    
    guard let leafSchema = subSchema.properties?["leaf"] else {
      Issue.record("Missing leafSchema")
      return
    }
    #expect(leafSchema.resolvedBaseURI?.absoluteString == "https://example.com/folder/file.json")
    
    guard let inheritedSchema = subSchema.properties?["inherited"] else {
      Issue.record("Missing inheritedSchema")
      return
    }
    #expect(inheritedSchema.resolvedBaseURI?.absoluteString == "https://example.com/folder/")
  }
}
