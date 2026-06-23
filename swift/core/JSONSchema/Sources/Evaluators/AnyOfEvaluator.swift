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

/// Evaluator for the "anyOf" keyword in JSON Schema.
public struct AnyOfEvaluator: KeywordEvaluator {
  private let subschemas: [SchemaNode]

  /// Initializes the AnyOfEvaluator compiling each subschema in the anyOf array.
  public init(
    data: JSONValue,
    identity: SchemaIdentity,
    compiler: SchemaCompiler
  ) throws {
    guard case .array(let schemas) = data else {
      throw SchemaCompilerError.invalidSchemaType
    }
    var compiled: [SchemaNode] = []
    for (index, schemaData) in schemas.enumerated() {
      let childIdentity = identity.appending(path: String(index))
      let compiledNode = try compiler.compile(
        schemaData: schemaData,
        identity: childIdentity
      )
      compiled.append(compiledNode)
    }
    self.subschemas = compiled
  }

  public func evaluate(
    instance: JSONValue,
    context: ValidationContext
  ) -> ValidationResult {
    var anyValid = false
    var childResults: [ValidationResult] = []

    for subschema in subschemas {
      do {
        let childContext = try context.incrementingDepth()
        let result = subschema.evaluate(instance: instance, context: childContext)
        if result.isValid {
          anyValid = true
        }
        childResults.append(result)
      } catch {
        let failureResult = ValidationResult(
          isValid: false,
          instanceLocation: context.instanceLocation,
          schemaLocation: subschema.identity,
          errors: [error.localizedDescription],
          annotations: [:],
          childResults: []
        )
        childResults.append(failureResult)
      }
    }

    if anyValid {
      return .success(childResults: childResults)
    } else {
      return .failure(
        error: "Instance did not validate against any of the subschemas in 'anyOf'.",
        childResults: childResults
      )
    }
  }
}
