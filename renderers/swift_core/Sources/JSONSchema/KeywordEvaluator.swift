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

/// A protocol for evaluators implementing individual JSON Schema keywords.
public protocol KeywordEvaluator: Sendable {
  /// Evaluates the JSON instance against the keyword's rules.
  /// - Parameters:
  ///   - instance: The JSON value being validated.
  ///   - context: The current validation context.
  /// - Returns: A ValidationResult containing validation status, errors, and annotations.
  func evaluate(instance: JSONValue, context: ValidationContext) -> ValidationResult
}
