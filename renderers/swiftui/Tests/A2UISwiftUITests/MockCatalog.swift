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

import A2UICore
import A2UISwiftUI
import JSONSchema
import SwiftUI

/// A mock catalog view that maps resolved nodes to SwiftUI views.
public struct MockCatalog: CatalogView {
  public let node: Node

  public init(node: Node) {
    self.node = node
  }

  public var body: some View {
    switch node.type {
    case "Text":
      let textBinding = node.properties["text"] as? DataBinding<String>
      Text(textBinding?.get() ?? "")
        .accessibilityIdentifier(node.id)
    case "Button":
      let label = node.properties["label"] as? String ?? ""
      let action = node.properties["onClick"] as? ResolvedAction
      Button(label) {
        action?()
      }
      .accessibilityIdentifier(node.id)
    case "VStack":
      VStack {
        if let children = node.properties["children"] as? [Node] {
          ForEach(children) { child in
            MockCatalog(node: child)
          }
        }
      }
      .accessibilityIdentifier(node.id)
    default:
      Text("Unknown: \(node.type)")
        .accessibilityIdentifier(node.id)
    }
  }
}

/// A mock component catalog that provides JSON schemas for validation.
public struct MockComponentCatalog: ComponentCatalog {
  private let schemas: [String: JSONSchema]

  /// Default schemas for common components used in testing.
  public static let defaultSchemas: [String: JSONSchema] = {
    let commonRef = "https://a2ui.org/schemas/v0_9_1/common.json#/$defs"
    return [
      "VStack": JSONSchema(
        types: [.object],
        properties: [
          "children": JSONSchema(ref: "\(commonRef)/ChildList")
        ]
      ),
      "Text": JSONSchema(
        types: [.object],
        properties: [
          "text": JSONSchema(ref: "\(commonRef)/DynamicString")
        ]
      ),
      "Button": JSONSchema(
        types: [.object],
        properties: [
          "label": JSONSchema(types: [.string]),
          "onClick": JSONSchema(ref: "\(commonRef)/Action"),
        ]
      ),
      "Input": JSONSchema(
        types: [.object],
        properties: [
          "value": JSONSchema(ref: "\(commonRef)/DynamicString")
        ]
      ),
    ]
  }()

  public init(schemas: [String: JSONSchema] = defaultSchemas) {
    self.schemas = schemas
  }

  public func schema(forType type: String) -> JSONSchema? {
    schemas[type]
  }

  public func makeTheme(jsonObject: JSONValue) -> (any SurfaceTheme)? {
    nil
  }

  public func localFunction(for name: String) -> (any LocalFunction)? {
    nil
  }
}
