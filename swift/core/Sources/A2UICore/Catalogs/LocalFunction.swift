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

import OrderedJSON

/// Abstract definition of local validation or transformation functions.
///
/// Implementations are registered in a `ComponentCatalog` and invoked
/// by the `SurfaceViewModel` when evaluating `FunctionCall` dynamic
/// values.
public protocol LocalFunction: Sendable {
  /// Evaluates the function with the given arguments.
  ///
  /// - Parameter arguments: A dictionary of named arguments.
  /// - Returns: The result of the function evaluation.
  /// - Throws: `LocalFunctionError` if evaluation fails.
  func evaluate(arguments: [String: JSONValue]) throws -> JSONValue
}
