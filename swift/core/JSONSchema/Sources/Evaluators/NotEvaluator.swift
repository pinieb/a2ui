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

/// Evaluator for the "not" keyword in JSON Schema.
public struct NotEvaluator: KeywordEvaluator {
  private let subschema: SchemaNode

  /// Initializes the NotEvaluator compiling the not subschema.
  public init(
    data: JSONValue,
    identity: SchemaIdentity,
    compiler: SchemaCompiler
  ) throws {
    self.subschema = try compiler.compile(schemaData: data, identity: identity)
  }

  public func evaluate(
    instance: JSONValue,
    context: ValidationContext
  ) -> ValidationResult {
    do {
      let childContext = try context.incrementingDepth()
      let result = subschema.evaluate(instance: instance, context: childContext)
      if result.isValid {
        return .failure(
          error: "Instance validation succeeded against the 'not' subschema, but must fail.",
          childResults: [result]
        )
      } else {
        return .success(childResults: [result])
      }
    } catch {
      return .failure(
        error: "Failed to evaluate 'not' subschema: \(error.localizedDescription)"
      )
    }
  }
}
