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

/// Evaluator for the "type" keyword in JSON Schema.
public struct TypeEvaluator: KeywordEvaluator {
  private let allowedTypes: Set<String>

  /// Initializes the TypeEvaluator with the schema definition.
  /// - Parameter schemaData: The JSONValue representing the allowed types
  ///   (string or array of strings).
  public init(allowedTypes schemaData: JSONValue) {
    switch schemaData {
    case .string(let typeStr):
      self.allowedTypes = [typeStr]
    case .array(let arrayVal):
      var types = Set<String>()
      for item in arrayVal {
        if case .string(let typeStr) = item {
          types.insert(typeStr)
        }
      }
      self.allowedTypes = types
    default:
      self.allowedTypes = []
    }
  }

  public func evaluate(instance: JSONValue, context: ValidationContext) -> ValidationResult {
    let instanceType = instance.typeName

    if allowedTypes.contains(instanceType) {
      return .success()
    }

    // JSON Schema quirk: an integer is also a valid number.
    if instanceType == "integer" && allowedTypes.contains("number") {
      return .success()
    }

    let sortedAllowed = allowedTypes.sorted().joined(separator: ", ")
    return .failure(
      error: "Instance type '\(instanceType)' is not one of: [\(sortedAllowed)]"
    )
  }
}
