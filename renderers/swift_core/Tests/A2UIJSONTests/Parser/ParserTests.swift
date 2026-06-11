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
}
