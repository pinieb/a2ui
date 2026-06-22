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

/// Compiles raw JSON Schema documents into executable `SchemaNode` trees.
public final class SchemaCompiler: Sendable {
  /// The schema registry used by this compiler for caching and resolving nodes.
  public let schemaRegistry: SchemaRegistry

  /// The keyword registry containing evaluator factories.
  public let keywordRegistry: KeywordRegistry

  /// Initializes a SchemaCompiler with a specific schema registry and keyword registry.
  /// - Parameters:
  ///   - schemaRegistry: The registry where compiled nodes are cached.
  ///   - keywordRegistry: The keyword registry.
  public init(
    schemaRegistry: SchemaRegistry,
    keywordRegistry: KeywordRegistry = KeywordRegistry()
  ) {
    self.schemaRegistry = schemaRegistry
    self.keywordRegistry = keywordRegistry
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
    switch schemaData {
    case .boolean(let val):
      let evaluator: any KeywordEvaluator =
        val ? AlwaysSucceedEvaluator() : AlwaysFailEvaluator()
      let node = SchemaNode(
        identity: identity,
        dynamicAnchor: nil,
        evaluators: [evaluator]
      )
      schemaRegistry.register(node, for: identity)
      return node

    case .object(let dict):
      var currentIdentity = identity

      // 1. $id interception
      if let idVal = dict["$id"], case .string(let idStr) = idVal {
        let resolvedURI: String
        if let base = URL(string: currentIdentity.baseURI),
          let resolved = URL(string: idStr, relativeTo: base)
        {
          resolvedURI = resolved.absoluteString
        } else {
          resolvedURI = idStr
        }
        currentIdentity = currentIdentity.updatingBaseURI(to: resolvedURI)
      }

      // 2. $defs interception
      if let defsVal = dict["$defs"], case .object(let defsDict) = defsVal {
        for (key, subSchema) in defsDict {
          let defsIdentity =
            currentIdentity
            .appending(path: "$defs")
            .appending(path: key)
          _ = try compile(
            schemaData: subSchema,
            identity: defsIdentity
          )
        }
      }

      // 3. $dynamicAnchor interception
      var parsedAnchor: String? = nil
      if let anchorVal = dict["$dynamicAnchor"], case .string(let anchorStr) = anchorVal {
        parsedAnchor = anchorStr
      }

      // 4. Standard Keyword Compilation
      var evaluators: [any KeywordEvaluator] = []
      for (keyword, value) in dict {
        if ["$id", "$defs", "$dynamicAnchor", "$schema"].contains(keyword) {
          continue
        }
        let keywordIdentity = currentIdentity.appending(path: keyword)
        if let evaluator = try keywordRegistry.makeEvaluator(
          for: keyword,
          data: value,
          identity: keywordIdentity,
          compiler: self
        ) {
          evaluators.append(evaluator)
        }
      }

      let node = SchemaNode(
        identity: currentIdentity,
        dynamicAnchor: parsedAnchor,
        evaluators: evaluators
      )
      schemaRegistry.register(node, for: currentIdentity)
      return node

    default:
      throw SchemaCompilerError.invalidSchemaType
    }
  }

  // MARK: - Helper Evaluators

  private struct AlwaysSucceedEvaluator: KeywordEvaluator {
    func evaluate(
      instance: JSONValue,
      context: ValidationContext
    ) -> ValidationResult {
      return .success()
    }
  }

  private struct AlwaysFailEvaluator: KeywordEvaluator {
    func evaluate(
      instance: JSONValue,
      context: ValidationContext
    ) -> ValidationResult {
      return .failure(
        error: "Schema validation failed (boolean false schema)"
      )
    }
  }
}
