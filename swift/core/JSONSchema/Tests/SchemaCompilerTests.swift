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

struct SchemaCompilerTests {

  // Dummy implementation of KeywordEvaluator for testing.
  private struct DummyKeywordEvaluator: KeywordEvaluator {
    func evaluate(
      instance: JSONValue,
      context: ValidationContext
    ) -> ValidationResult {
      return .success()
    }
  }

  @Test func testBooleanSchemas() throws {
    let registry = SchemaRegistry()
    let compiler = SchemaCompiler(schemaRegistry: registry)
    let identity = SchemaIdentity(uri: "https://example.com/schema")

    let trueNode = try compiler.compile(
      schemaData: .boolean(true),
      identity: identity
    )
    let falseNode = try compiler.compile(
      schemaData: .boolean(false),
      identity: identity
    )

    let context = ValidationContext(schemaRegistry: registry)

    let trueResult = trueNode.evaluate(instance: .object([:]), context: context)
    #expect(trueResult.isValid == true)

    let falseResult = falseNode.evaluate(instance: .object([:]), context: context)
    #expect(falseResult.isValid == false)
  }

  @Test func testIDScopeReset() throws {
    let registry = SchemaRegistry()
    var keywordRegistry = KeywordRegistry()

    // Register a dummy properties evaluator that compiles sub-schemas.
    keywordRegistry.register(keyword: "properties") { data, identity, compiler in
      if case .object(let dict) = data {
        for (key, subSchema) in dict {
          _ = try compiler.compile(
            schemaData: subSchema,
            identity: identity.appending(path: key)
          )
        }
      }
      return DummyKeywordEvaluator()
    }

    let compiler = SchemaCompiler(
      schemaRegistry: registry,
      keywordRegistry: keywordRegistry
    )

    let rootSchema: JSONValue = .object([
      "properties": .object([
        "child": .object([
          "$id": .string("https://test.com/child")
        ])
      ])
    ])

    let identity = SchemaIdentity(uri: "https://example.com/root")
    _ = try compiler.compile(schemaData: rootSchema, identity: identity)

    let resolved = try #require(registry.resolve(uri: "https://test.com/child"))
    #expect(resolved.identity.baseURI == "https://test.com/child")
    #expect(resolved.identity.pointer.segments.isEmpty)
  }

  @Test func testDefsCaching() throws {
    let registry = SchemaRegistry()
    let compiler = SchemaCompiler(schemaRegistry: registry)

    let rootSchema: JSONValue = .object([
      "$defs": .object([
        "user": .boolean(true)
      ])
    ])

    let identity = SchemaIdentity(uri: "https://example.com/root")
    _ = try compiler.compile(schemaData: rootSchema, identity: identity)

    let defURI = "https://example.com/root#/$defs/user"
    let resolved = try #require(registry.resolve(uri: defURI))
    #expect(resolved.identity.fullURI == defURI)
  }
}
