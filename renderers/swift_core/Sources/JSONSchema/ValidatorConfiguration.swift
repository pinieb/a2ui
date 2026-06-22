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

/// Configuration options for the JSON Schema Validator.
public struct ValidatorConfiguration: Sendable {
  /// The maximum execution/recursion depth allowed during evaluation.
  public var maxEvaluationDepth: Int

  /// Whether format assertions are enabled.
  public var isFormatAssertionEnabled: Bool

  /// Initializes a ValidatorConfiguration with default values.
  public init(
    maxEvaluationDepth: Int = 100,
    isFormatAssertionEnabled: Bool = false
  ) {
    self.maxEvaluationDepth = maxEvaluationDepth
    self.isFormatAssertionEnabled = isFormatAssertionEnabled
  }
}
