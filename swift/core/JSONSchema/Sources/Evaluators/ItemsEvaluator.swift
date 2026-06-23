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

/// Evaluator for the "items" keyword in JSON Schema.
public struct ItemsEvaluator: KeywordEvaluator {
  private let itemSchema: SchemaNode

  /// Initializes the ItemsEvaluator compiling the items subschema.
  public init(
    data: JSONValue,
    identity: SchemaIdentity,
    compiler: SchemaCompiler
  ) throws {
    self.itemSchema = try compiler.compile(schemaData: data, identity: identity)
  }

  public func evaluate(
    instance: JSONValue,
    context: ValidationContext
  ) -> ValidationResult {
    guard case .array(let elements) = instance else {
      return .success()
    }

    var isValid = true
    var childResults: [ValidationResult] = []

    for (index, element) in elements.enumerated() {
      do {
        let childContext = try context.passingDown(toInstanceIndex: index)
        let result = itemSchema.evaluate(instance: element, context: childContext)
        if !result.isValid {
          isValid = false
        }
        childResults.append(result)
      } catch {
        isValid = false
        let failureResult = ValidationResult(
          isValid: false,
          instanceLocation: context.instanceLocation.appending(segment: String(index)),
          schemaLocation: itemSchema.identity,
          errors: [error.localizedDescription],
          annotations: [:],
          childResults: []
        )
        childResults.append(failureResult)
      }
    }

    if isValid {
      return .success(childResults: childResults)
    } else {
      return .failure(
        error: "Array items validation failed.",
        childResults: childResults
      )
    }
  }
}
