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

struct ExecutionContractsTests {

  @Test func testContextDepthLimit() throws {
    let config = ValidatorConfiguration(maxEvaluationDepth: 3)
    let context = ValidationContext(configuration: config)

    // Call passingDown 3 times successfully.
    let ctx1 = try context.passingDown(toInstanceKey: "a")
    let ctx2 = try ctx1.passingDown(toInstanceKey: "b")
    let ctx3 = try ctx2.passingDown(toInstanceKey: "c")

    #expect(ctx3.depth == 3)

    // Assert that the 4th call throws the max depth error.
    #expect(throws: ValidationError.maxDepthExceeded) {
      _ = try ctx3.passingDown(toInstanceKey: "d")
    }
  }

  // Dummy implementation of KeywordEvaluator for testing.
  struct DummyEvaluator: KeywordEvaluator {
    let evaluateBlock: @Sendable (JSONValue, ValidationContext) -> ValidationResult

    func evaluate(instance: JSONValue, context: ValidationContext) -> ValidationResult {
      return evaluateBlock(instance, context)
    }
  }

  @Test func testNodeAggregationPass() throws {
    let evaluatorA = DummyEvaluator { _, _ in
      .success(annotations: ["a": .string("A")])
    }
    let evaluatorB = DummyEvaluator { _, _ in
      .success(annotations: ["b": .string("B")])
    }

    let node = SchemaNode(
      identity: SchemaIdentity(baseURI: "https://example.com/test"),
      evaluators: [evaluatorA, evaluatorB]
    )

    let context = ValidationContext()
    let result = node.evaluate(instance: .null, context: context)

    #expect(result.isValid == true)
    #expect(result.annotations == ["a": .string("A"), "b": .string("B")])
  }

  @Test func testNodeAggregationFail() throws {
    let evaluatorFail = DummyEvaluator { _, _ in
      .failure(error: "Failure from dummy")
    }
    let evaluatorPass = DummyEvaluator { _, _ in
      .success(annotations: ["x": .string("X")])
    }

    let node = SchemaNode(
      identity: SchemaIdentity(baseURI: "https://example.com/test"),
      evaluators: [evaluatorFail, evaluatorPass]
    )

    let context = ValidationContext()
    let result = node.evaluate(instance: .null, context: context)

    #expect(result.isValid == false)
    #expect(result.errors.contains("Failure from dummy"))
  }
}
