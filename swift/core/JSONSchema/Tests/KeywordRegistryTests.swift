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

struct KeywordRegistryTests {

  // Dummy implementation of KeywordEvaluator for testing keyword factory.
  private struct DummyKeywordEvaluator: KeywordEvaluator {
    func evaluate(instance: JSONValue, context: ValidationContext) -> ValidationResult {
      return .success()
    }
  }

  @Test func testKeywordFactoryInjection() throws {
    var registry = KeywordRegistry()
    registry.register(keyword: "dummyRule") { data, identity, compiler in
      return DummyKeywordEvaluator()
    }

    let schemaRegistry = SchemaRegistry()
    let compiler = SchemaCompiler(schemaRegistry: schemaRegistry)
    let identity = try #require(SchemaIdentity(uri: "https://example.com/schema"))

    let optionalEvaluator = try registry.makeEvaluator(
      for: "dummyRule",
      data: .null,
      identity: identity,
      compiler: compiler
    )
    let evaluator = try #require(optionalEvaluator)

    #expect(evaluator is DummyKeywordEvaluator)
  }

  @Test func testUnknownKeywords() throws {
    let registry = KeywordRegistry()
    let schemaRegistry = SchemaRegistry()
    let compiler = SchemaCompiler(schemaRegistry: schemaRegistry)
    let identity = try #require(SchemaIdentity(uri: "https://example.com/schema"))

    let evaluator = try registry.makeEvaluator(
      for: "unknownRule",
      data: .null,
      identity: identity,
      compiler: compiler
    )

    #expect(evaluator == nil)
  }
}
