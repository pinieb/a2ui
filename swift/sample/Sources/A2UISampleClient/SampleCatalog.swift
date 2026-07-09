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
import A2UIJSON
import A2UISwiftUI
import JSONSchema
import OrderedJSON
import SwiftUI

/// A component catalog for the A2UI demo app.
///
/// Provides schemas and a `CatalogView` for a set of basic UI
/// components: Text, Button, Row, Column, Image, TextField, CheckBox,
/// Card, and Divider.
public struct SampleCatalog: ComponentCatalog {
  private let schemas: [String: Schema]

  public init() throws {
    let remote = A2UICommonSchema.allSchemas

    func makeSchema(_ json: String) throws -> Schema {
      try Schema(instance: json, remoteSchemas: remote)
    }

    let commonProps = """
      "id": {"type": "string"},
      "component": {"type": "string"}
      """

    schemas = [
      "text": try makeSchema("""
        {"type": "object", "properties": {
          \(commonProps),
          "text": {"$ref": "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/DynamicString"}
        }, "required": ["id", "component"]}
        """),
      "button": try makeSchema("""
        {"type": "object", "properties": {
          \(commonProps),
          "label": {"$ref": "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/DynamicString"},
          "onClick": {"$ref": "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/Action"}
        }, "required": ["id", "component"]}
        """),
      "row": try makeSchema("""
        {"type": "object", "properties": {
          \(commonProps),
          "children": {"$ref": "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/ChildList"}
        }, "required": ["id", "component"]}
        """),
      "column": try makeSchema("""
        {"type": "object", "properties": {
          \(commonProps),
          "children": {"$ref": "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/ChildList"}
        }, "required": ["id", "component"]}
        """),
      "image": try makeSchema("""
        {"type": "object", "properties": {
          \(commonProps),
          "url": {"$ref": "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/DynamicString"},
          "alt": {"$ref": "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/DynamicString"}
        }, "required": ["id", "component"]}
        """),
      "textField": try makeSchema("""
        {"type": "object", "properties": {
          \(commonProps),
          "value": {"$ref": "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/DynamicString"},
          "placeholder": {"$ref": "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/DynamicString"}
        }, "required": ["id", "component"]}
        """),
      "checkBox": try makeSchema("""
        {"type": "object", "properties": {
          \(commonProps),
          "checked": {"$ref": "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/DynamicBoolean"},
          "label": {"$ref": "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/DynamicString"}
        }, "required": ["id", "component"]}
        """),
      "card": try makeSchema("""
        {"type": "object", "properties": {
          \(commonProps),
          "children": {"$ref": "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/ChildList"}
        }, "required": ["id", "component"]}
        """),
      "divider": try makeSchema("""
        {"type": "object", "properties": {
          \(commonProps)
        }, "required": ["id", "component"]}
        """),
    ]
  }

  public func schema(forType type: String) -> Schema? {
    schemas[type]
  }

  public func makeTheme(jsonObject: JSONValue) -> (any SurfaceTheme)? {
    guard let dict = jsonObject.dictionaryValue else { return nil }
    return SampleTheme(
      primaryColor: dict["primaryColor"]?.stringValue ?? "#1A73E8",
      iconUrl: dict["iconUrl"]?.stringValue,
      agentDisplayName: dict["agentDisplayName"]?.stringValue ?? "A2UI Agent"
    )
  }

  public func localFunction(for name: String) -> (any LocalFunction)? {
    nil
  }
}

// MARK: - Sample Catalog View

/// Renders any component in the sample catalog.
public struct SampleCatalogView: CatalogView {
  public let node: Node

  public init(node: Node) {
    self.node = node
  }

  public var body: some View {
    switch node.type {
    case "text":
      TextView(node: node)
    case "button":
      ButtonView(node: node)
    case "row":
      RowView(node: node)
    case "column":
      ColumnView(node: node)
    case "image":
      ImageView(node: node)
    case "textField":
      TextFieldView(node: node)
    case "checkBox":
      CheckBoxView(node: node)
    case "card":
      CardView(node: node)
    case "divider":
      Divider()
    default:
      Text("Unknown: \(node.type)")
        .foregroundStyle(.secondary)
    }
  }
}

// MARK: - Component Views

private struct TextView: View {
  let node: Node
  var body: some View {
    if let text = node.properties["text"] as? DataBinding<String> {
      Text(text.get())
    } else if let text = node.properties["text"] as? String {
      Text(text)
    } else {
      Text("")
    }
  }
}

private struct ButtonView: View {
  let node: Node
  var body: some View {
    let label = (node.properties["label"] as? DataBinding<String>)?.get()
      ?? (node.properties["label"] as? String)
      ?? "Button"
    let action = node.properties["onClick"] as? ResolvedAction

    Button(action: { action?() }) {
      Text(label)
    }
    .buttonStyle(.borderedProminent)
  }
}

private struct RowView: View {
  let node: Node
  var body: some View {
    HStack(spacing: 8) {
      ForEach(Array(node.children.enumerated()), id: \.offset) { _, child in
        SampleCatalogView(node: child)
      }
    }
  }
}

private struct ColumnView: View {
  let node: Node
  var body: some View {
    VStack(spacing: 8) {
      ForEach(Array(node.children.enumerated()), id: \.offset) { _, child in
        SampleCatalogView(node: child)
      }
    }
  }
}

private struct ImageView: View {
  let node: Node
  var body: some View {
    let url = (node.properties["url"] as? DataBinding<String>)?.get()
      ?? (node.properties["url"] as? String)
      ?? ""
    AsyncImage(url: URL(string: url)) { image in
      image.resizable().scaledToFit()
    } placeholder: {
      ProgressView()
    }
    .frame(maxWidth: 200, maxHeight: 150)
  }
}

private struct TextFieldView: View {
  let node: Node
  @State private var localText = ""
  var body: some View {
    let placeholder = (node.properties["placeholder"] as? DataBinding<String>)?.get()
      ?? (node.properties["placeholder"] as? String)
      ?? "Enter text..."

    if let binding = node.properties["value"] as? DataBinding<String> {
      TextField(placeholder, text: binding.swiftUIBinding)
        .textFieldStyle(.roundedBorder)
    } else {
      TextField(placeholder, text: $localText)
        .textFieldStyle(.roundedBorder)
    }
  }
}

private struct CheckBoxView: View {
  let node: Node
  var body: some View {
    let label = (node.properties["label"] as? DataBinding<String>)?.get()
      ?? (node.properties["label"] as? String)
      ?? ""

    if let binding = node.properties["checked"] as? DataBinding<Bool> {
      Toggle(label, isOn: binding.swiftUIBinding)
    } else {
      Text(label)
    }
  }
}

private struct CardView: View {
  let node: Node
  var body: some View {
    VStack(spacing: 8) {
      ForEach(Array(node.children.enumerated()), id: \.offset) { _, child in
        SampleCatalogView(node: child)
      }
    }
    .padding()
    .background(.regularMaterial)
    .clipShape(RoundedRectangle(cornerRadius: 12))
  }
}
