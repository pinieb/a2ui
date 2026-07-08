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

import JSONSchema
import OrderedJSON

/// A registry and factory for components, schemas, and local functions.
///
/// Implementations provide component schemas (compiled from JSON Schema
/// definitions), theme parsing, and local function lookup.
public protocol ComponentCatalog: Sendable {
  /// Returns the compiled schema for the given component type.
  ///
  /// - Parameter type: The component type identifier.
  /// - Returns: A `Schema` if registered, otherwise `nil`.
  func schema(forType type: String) -> Schema?

  /// Parses a raw theme payload into a theme.
  ///
  /// - Parameter jsonObject: The raw theme JSON value.
  /// - Returns: A `SurfaceTheme` if parsing succeeds, otherwise `nil`.
  func makeTheme(jsonObject: JSONValue) -> (any SurfaceTheme)?

  /// Returns a local function implementation.
  ///
  /// - Parameter name: The function name.
  /// - Returns: A `LocalFunction` if registered, otherwise `nil`.
  func localFunction(for name: String) -> (any LocalFunction)?
}
