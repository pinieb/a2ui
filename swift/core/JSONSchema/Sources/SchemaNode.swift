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

/// Represents a compiled JSON Schema object (a schema node).
public struct SchemaNode: Sendable {
  /// The identity (URI and internal pointer) of this schema node.
  public let identity: SchemaIdentity

  /// The keyword evaluators defined for this schema node.
  public let evaluators: [any KeywordEvaluator]

  /// Initializes a new SchemaNode.
  public init(identity: SchemaIdentity, evaluators: [any KeywordEvaluator]) {
    self.identity = identity
    self.evaluators = evaluators
  }

  /// Evaluates a JSON instance against all registered keyword evaluators.
  /// - Parameters:
  ///   - instance: The JSON value to validate.
  ///   - context: The current validation context.
  /// - Returns: A ValidationResult representing the aggregated outcome of all evaluators.
  public func evaluate(instance: JSONValue, context: ValidationContext) -> ValidationResult {
    var isValid = true
    var errors: [String] = []
    var annotations: [String: JSONValue] = [:]
    var childResults: [ValidationResult] = []

    for evaluator in evaluators {
      let result = evaluator.evaluate(instance: instance, context: context)
      if !result.isValid {
        isValid = false
      }
      errors.append(contentsOf: result.errors)
      annotations.merge(result.annotations) { _, new in new }
      childResults.append(contentsOf: result.childResults)
    }

    return ValidationResult(
      isValid: isValid,
      instanceLocation: context.instanceLocation,
      schemaLocation: identity,
      errors: errors,
      annotations: isValid ? annotations : [:],
      childResults: childResults
    )
  }
}
