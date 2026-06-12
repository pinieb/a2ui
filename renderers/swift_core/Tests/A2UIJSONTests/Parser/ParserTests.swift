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
    let objectSchema = try #require(schema as? SchemaObject)
    let nameProp = try #require(
      objectSchema.properties.first(where: { $0.name == "name" })
    )
    #expect(nameProp.type is SchemaString)
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
    let anyOf = try #require(anyOfSchema as? SchemaAnyOf)
    #expect(anyOf.subschemas.count == 2)
    #expect(anyOf.subschemas[0] is SchemaString)
    #expect(anyOf.subschemas[1] is SchemaInteger)

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
    let allOf = try #require(allOfSchema as? SchemaAllOf)
    #expect(allOf.subschemas.count == 2)
    let firstObject = try #require(allOf.subschemas[0] as? SchemaObject)
    #expect(
      firstObject.properties.contains(where: { $0.name == "name" })
    )
  }

  @Test
  func `Validation successfully annotates matched schema IDs`() throws {
    let stub = ExternalSchemaStub(
      uri: "https://a2ui.dev/schema/v1/component.json"
    )
    let schema = SchemaObject {
      SchemaProperty(name: "component", type: SchemaReference(stub))
    }
    let instance = JSONValue.object([
      "component": .object([:])
    ])
    let output = try schema.validate(instance: instance)

    #expect(output.matchedSchemaIDs.isEmpty)
    let child = try #require(output.children["component"])
    #expect(
      child.matchedSchemaIDs.contains(
        "https://a2ui.dev/schema/v1/component.json"
      )
    )
  }

  @Test
  func `Validation throws detailed errors on type mismatch`() throws {
    let schema = SchemaInteger()
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
    let schema = SchemaObject {
      SchemaProperty(name: "id", type: SchemaString(), isRequired: true)
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
    let localSchema = SchemaString()
    let stub = ExternalSchemaStub(
      uri: "https://a2ui.dev/schema/v1/component.json",
      localSchema: localSchema
    )
    let schema = SchemaObject {
      SchemaProperty(name: "component", type: SchemaReference(stub))
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
    let stub = ExternalSchemaStub(
      uri: "https://a2ui.dev/schema/v1/component.json"
    ) {
      SchemaProperty(name: "id", type: SchemaString(), isRequired: true)
      SchemaProperty(name: "label", type: SchemaString())
    }
    let instance = JSONValue.object([
      "id": .string("comp123"),
      "label": .string("Click Me"),
    ])
    let output = try stub.validate(instance: instance)

    #expect(
      output.matchedSchemaIDs.contains(
        "https://a2ui.dev/schema/v1/component.json"
      )
    )
    #expect(output.children["id"] != nil)
    #expect(output.children["label"] != nil)
  }

  @Test
  func `Validation rejects additional properties when forbidden`() throws {
    let schema = SchemaObject(additionalProperties: false) {
      SchemaProperty(name: "path", type: SchemaString(), isRequired: true)
    }

    let printed = try schema.print(
      bundleExternalRefs: false,
      sorting: .alphabetical,
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
      #expect(error.message.contains("extra"))
    } catch {
      Issue.record("Expected ValidationError, but got: \(error)")
    }
  }

  @Test
  func `Parser decodes boolean schemas`() throws {
    let trueSchema = try JSONSchema.parse("true")
    #expect(trueSchema is SchemaAny)
    let trueOutput = try trueSchema.validate(instance: .string("any-value"))
    #expect(trueOutput.instance == .string("any-value"))

    let falseSchema = try JSONSchema.parse("false")
    #expect(falseSchema is SchemaNone)
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
    let arraySchema = try #require(schema as? SchemaArray)
    #expect(arraySchema.items is SchemaAny)

    // And validates successfully
    let output = try arraySchema.validate(instance: .array([.string("any"), .number(123)]))
    #expect(output.children.count == 2)
  }

  @Test
  func `Validators ignore non-applicable types`() throws {
    // 1. Implicit schemas (omitType = true) ignore non-applicable types
    let implicitObjectSchema = SchemaObject(omitType: true) {
      SchemaProperty(name: "name", type: SchemaString())
    }
    let stringInstance = JSONValue.string("not-an-object")
    let implicitObjectOutput = try implicitObjectSchema.validate(instance: stringInstance)
    #expect(implicitObjectOutput.instance == stringInstance)

    let implicitArraySchema = SchemaArray(items: SchemaString(), omitType: true)
    let implicitArrayOutput = try implicitArraySchema.validate(instance: stringInstance)
    #expect(implicitArrayOutput.instance == stringInstance)

    // 2. Explicit schemas (omitType = false) enforce type constraints
    let explicitObjectSchema = SchemaObject(omitType: false) {
      SchemaProperty(name: "name", type: SchemaString())
    }
    #expect(throws: ValidationError.self) {
      try explicitObjectSchema.validate(instance: stringInstance)
    }

    let explicitArraySchema = SchemaArray(items: SchemaString(), omitType: false)
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
    #expect(schema is SchemaOneOf)

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
    #expect(schema is SchemaNot)

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
    let objectSchema = try #require(schema as? SchemaObject)
    #expect(objectSchema.patternProperties?.count == 2)

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
}

