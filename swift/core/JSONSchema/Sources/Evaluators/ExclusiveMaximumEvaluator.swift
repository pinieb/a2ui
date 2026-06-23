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

/// Evaluator for the "exclusiveMaximum" keyword in JSON Schema.
public struct ExclusiveMaximumEvaluator: KeywordEvaluator {
  private let limit: JSONValue

  /// Initializes the ExclusiveMaximumEvaluator.
  /// - Parameter limitValue: The JSONValue containing the exclusive maximum limit.
  public init(limit limitValue: JSONValue) {
    self.limit = limitValue
  }

  public func evaluate(instance: JSONValue, context: ValidationContext) -> ValidationResult {
    guard let comp = instance.compareNumeric(to: limit) else {
      return .success()
    }

    if comp == .orderedAscending {
      return .success()
    }

    return .failure(
      error: "Instance value is greater than or equal to exclusiveMaximum limit."
    )
  }
}
