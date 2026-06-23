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

/// Evaluator for the "enum" keyword in JSON Schema.
public struct EnumEvaluator: KeywordEvaluator {
  private let allowedValues: [JSONValue]

  /// Initializes the EnumEvaluator with the schema's enum array.
  /// - Parameter allowedValues: The JSONValue representing the array of allowed values.
  public init(allowedValues: JSONValue) {
    if case .array(let arr) = allowedValues {
      self.allowedValues = arr
    } else {
      self.allowedValues = []
    }
  }

  public func evaluate(instance: JSONValue, context: ValidationContext) -> ValidationResult {
    if allowedValues.contains(instance) {
      return .success()
    }
    return .failure(
      error: "Instance value is not present in the allowed enum values."
    )
  }
}
