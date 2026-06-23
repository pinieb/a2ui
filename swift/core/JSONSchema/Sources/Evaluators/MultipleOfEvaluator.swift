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

/// Evaluator for the "multipleOf" keyword in JSON Schema.
public struct MultipleOfEvaluator: KeywordEvaluator {
  private let divisor: Double

  /// Initializes the MultipleOfEvaluator.
  /// - Parameter divisorValue: The JSONValue containing the divisor.
  public init(divisor divisorValue: JSONValue) {
    self.divisor = divisorValue.doubleValue ?? 1.0
  }

  public func evaluate(instance: JSONValue, context: ValidationContext) -> ValidationResult {
    guard let value = instance.doubleValue else {
      return .success()
    }

    guard divisor > 0 else {
      return .failure(error: "multipleOf divisor must be greater than 0.")
    }

    let division = value / divisor
    let difference = abs(division - division.rounded())
    if difference < 1e-9 {
      return .success()
    }

    return .failure(
      error: "Instance value \(value) is not a multiple of \(divisor)."
    )
  }
}
