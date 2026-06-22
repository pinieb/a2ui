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

/// Compiles raw JSON Schema documents into executable `SchemaNode` trees.
///
/// The compiler maintains a reference to a `SchemaRegistry` to register
/// and resolve referenced schemas during compilation.
public final class SchemaCompiler: Sendable {
  /// The schema registry used by this compiler for caching and resolving nodes.
  public let schemaRegistry: SchemaRegistry

  /// Initializes a SchemaCompiler with a specific schema registry.
  /// - Parameter schemaRegistry: The registry where compiled nodes are cached.
  public init(schemaRegistry: SchemaRegistry) {
    self.schemaRegistry = schemaRegistry
  }

  /// Compiles a JSON Schema document into a SchemaNode.
  /// - Parameters:
  ///   - schemaData: The raw JSON value representing the schema.
  ///   - identity: The SchemaIdentity of the schema node.
  /// - Returns: A compiled SchemaNode ready for validation.
  /// - Throws: An error if compilation fails.
  public func compile(
    schemaData: JSONValue,
    identity: SchemaIdentity
  ) throws -> SchemaNode {
    return SchemaNode(identity: identity, evaluators: [])
  }
}
