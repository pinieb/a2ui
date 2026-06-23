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

/// Evaluator for the "const" keyword in JSON Schema.
public struct ConstEvaluator: KeywordEvaluator {
  private let expectedValue: JSONValue

  /// Initializes the ConstEvaluator with the schema's const value.
  /// - Parameter expectedValue: The expected JSON value.
  public init(expectedValue: JSONValue) {
    self.expectedValue = expectedValue
  }

  public func evaluate(instance: JSONValue, context: ValidationContext) -> ValidationResult {
    if instance == expectedValue {
      return .success()
    }
    return .failure(
      error: "Instance value does not match the expected constant value."
    )
  }
}
