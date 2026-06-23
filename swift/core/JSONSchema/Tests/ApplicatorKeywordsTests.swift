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
import JSONSchema
import Testing

struct ApplicatorKeywordsTests {

  @Test func testObjectTraversal() throws {
    let registry = SchemaRegistry()
    let compiler = SchemaCompiler(schemaRegistry: registry)
    let identity = try #require(SchemaIdentity(uri: "https://example.com/schema"))

    let schema: JSONValue = .object([
      "properties": .object([
        "name": .object(["type": .array([.string("string")])]),
        "age": .object(["type": .array([.string("integer")])])
      ])
    ])

    let node = try compiler.compile(schemaData: schema, identity: identity)
    let context = ValidationContext(schemaRegistry: registry)

    // Valid object
    let validInstance: JSONValue = .object([
      "name": .string("Alice"),
      "age": .integer(30)
    ])
    let result1 = node.evaluate(instance: validInstance, context: context)
    #expect(result1.isValid == true)

    // Invalid object (age is a string instead of integer)
    let invalidInstance: JSONValue = .object([
      "name": .string("Alice"),
      "age": .string("thirty")
    ])
    let result2 = node.evaluate(instance: invalidInstance, context: context)
    #expect(result2.isValid == false)

    // Verify the path is tracked correctly.
    let ageResult = result2.childResults.first {
      $0.instanceLocation.stringRepresentation == "#/age"
    }
    let ageNodeResult = try #require(ageResult)
    #expect(ageNodeResult.isValid == false)
  }

  @Test func testArrayTraversal() throws {
    let registry = SchemaRegistry()
    let compiler = SchemaCompiler(schemaRegistry: registry)
    let identity = try #require(SchemaIdentity(uri: "https://example.com/schema"))

    let schema: JSONValue = .object([
      "items": .object([
        "type": .array([.string("string")])
      ])
    ])

    let node = try compiler.compile(schemaData: schema, identity: identity)
    let context = ValidationContext(schemaRegistry: registry)

    // Valid array of strings
    let validArray: JSONValue = .array([.string("a"), .string("b")])
    let result1 = node.evaluate(instance: validArray, context: context)
    #expect(result1.isValid == true)

    // Invalid array containing a number at index 1
    let invalidArray: JSONValue = .array([.string("a"), .number(42.0), .string("c")])
    let result2 = node.evaluate(instance: invalidArray, context: context)
    #expect(result2.isValid == false)

    // Verify error at index 1 path.
    let itemResult = result2.childResults.first {
      $0.instanceLocation.stringRepresentation == "#/1"
    }
    let itemNodeResult = try #require(itemResult)
    #expect(itemNodeResult.isValid == false)
  }

  @Test func testLogicalCompositionAllOf() throws {
    let registry = SchemaRegistry()
    let compiler = SchemaCompiler(schemaRegistry: registry)
    let identity = try #require(SchemaIdentity(uri: "https://example.com/schema"))

    let schema: JSONValue = .object([
      "allOf": .array([
        .object(["type": .array([.string("number")])]),
        .object(["maximum": .integer(10)])
      ])
    ])

    let node = try compiler.compile(schemaData: schema, identity: identity)
    let context = ValidationContext(schemaRegistry: registry)

    // Passes both number type and max 10
    let validVal = JSONValue.number(5.5)
    let result1 = node.evaluate(instance: validVal, context: context)
    #expect(result1.isValid == true)

    // Fails because of maximum 10
    let invalidVal1 = JSONValue.number(12.0)
    let result2 = node.evaluate(instance: invalidVal1, context: context)
    #expect(result2.isValid == false)

    // Fails because of type string
    let invalidVal2 = JSONValue.string("not a number")
    let result3 = node.evaluate(instance: invalidVal2, context: context)
    #expect(result3.isValid == false)
  }

  @Test func testLogicalCompositionAnyOf() throws {
    let registry = SchemaRegistry()
    let compiler = SchemaCompiler(schemaRegistry: registry)
    let identity = try #require(SchemaIdentity(uri: "https://example.com/schema"))

    let schema: JSONValue = .object([
      "anyOf": .array([
        .object(["type": .array([.string("string")])]),
        .object(["type": .array([.string("integer")])])
      ])
    ])

    let node = try compiler.compile(schemaData: schema, identity: identity)
    let context = ValidationContext(schemaRegistry: registry)

    // Passes string
    let stringVal = JSONValue.string("hello")
    #expect(node.evaluate(instance: stringVal, context: context).isValid == true)

    // Passes integer
    let intVal = JSONValue.integer(42)
    #expect(node.evaluate(instance: intVal, context: context).isValid == true)

    // Fails boolean
    let boolVal = JSONValue.boolean(true)
    #expect(node.evaluate(instance: boolVal, context: context).isValid == false)
  }

  @Test func testLogicalCompositionNot() throws {
    let registry = SchemaRegistry()
    let compiler = SchemaCompiler(schemaRegistry: registry)
    let identity = try #require(SchemaIdentity(uri: "https://example.com/schema"))

    let schema: JSONValue = .object([
      "not": .object([
        "type": .array([.string("string")])
      ])
    ])

    let node = try compiler.compile(schemaData: schema, identity: identity)
    let context = ValidationContext(schemaRegistry: registry)

    // Passes integer (not a string)
    let intVal = JSONValue.integer(42)
    #expect(node.evaluate(instance: intVal, context: context).isValid == true)

    // Fails string
    let stringVal = JSONValue.string("hello")
    #expect(node.evaluate(instance: stringVal, context: context).isValid == false)
  }
}
