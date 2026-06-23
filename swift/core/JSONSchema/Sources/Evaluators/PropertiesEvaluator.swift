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

/// Evaluator for the "properties" keyword in JSON Schema.
public struct PropertiesEvaluator: KeywordEvaluator {
  private let properties: [String: SchemaNode]

  /// Initializes the PropertiesEvaluator compiling each property's schema.
  public init(
    data: JSONValue,
    identity: SchemaIdentity,
    compiler: SchemaCompiler
  ) throws {
    guard case .object(let dict) = data else {
      throw SchemaCompilerError.invalidSchemaType
    }
    var compiledProperties: [String: SchemaNode] = [:]
    for (key, value) in dict {
      let childIdentity = identity.appending(path: key)
      let compiledNode = try compiler.compile(schemaData: value, identity: childIdentity)
      compiledProperties[key] = compiledNode
    }
    self.properties = compiledProperties
  }

  public func evaluate(
    instance: JSONValue,
    context: ValidationContext
  ) -> ValidationResult {
    guard case .object(let dict) = instance else {
      return .success()
    }

    var isValid = true
    var childResults: [ValidationResult] = []

    for (key, value) in dict {
      if let childNode = properties[key] {
        do {
          let childContext = try context.passingDown(toInstanceKey: key)
          let result = childNode.evaluate(instance: value, context: childContext)
          if !result.isValid {
            isValid = false
          }
          childResults.append(result)
        } catch {
          isValid = false
          let failureResult = ValidationResult(
            isValid: false,
            instanceLocation: context.instanceLocation.appending(segment: key),
            schemaLocation: childNode.identity,
            errors: [error.localizedDescription],
            annotations: [:],
            childResults: []
          )
          childResults.append(failureResult)
        }
      }
    }

    if isValid {
      return .success(childResults: childResults)
    } else {
      return .failure(
        error: "Object property validation failed.",
        childResults: childResults
      )
    }
  }
}
