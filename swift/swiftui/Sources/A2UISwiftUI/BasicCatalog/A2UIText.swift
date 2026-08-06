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
import OrderedJSON
import SwiftUI

/// SwiftUI component view for the A2UI Basic Catalog `Text` component.
public struct A2UIText: View {
  public let node: Node

  public init(node: Node) {
    self.node = node
  }

  private var textContent: String {
    if let binding = node.properties["text"] as? DataBinding<String> {
      return binding.get()
    }
    if let str = node.properties["text"] as? String {
      return str
    }
    if let json = node.properties["text"] as? JSONValue {
      return json.stringValue ?? ""
    }
    return ""
  }

  private var variant: String {
    if let v = node.properties["variant"] as? String {
      return v
    }
    if let json = node.properties["variant"] as? JSONValue {
      return json.stringValue ?? "body"
    }
    return "body"
  }

  public var body: some View {
    textForVariant(textContent, variant: variant)
      .accessibilityLabel(accessibilityLabel)
  }

  @ViewBuilder
  private func textForVariant(_ text: String, variant: String) -> some View {
    switch variant {
    case "h1":
      Text(LocalizedStringKey(text))
        .font(.system(size: 32, weight: .bold))
    case "h2":
      Text(LocalizedStringKey(text))
        .font(.system(size: 26, weight: .bold))
    case "h3":
      Text(LocalizedStringKey(text))
        .font(.system(size: 22, weight: .semibold))
    case "h4":
      Text(LocalizedStringKey(text))
        .font(.system(size: 18, weight: .semibold))
    case "h5":
      Text(LocalizedStringKey(text))
        .font(.system(size: 16, weight: .medium))
    case "caption":
      Text(LocalizedStringKey(text))
        .font(.caption)
        .italic()
        .foregroundStyle(.secondary)
    default:
      Text(LocalizedStringKey(text))
        .font(.body)
    }
  }

  private var accessibilityLabel: String {
    if let accessibility = node.properties["accessibility"] as? JSONValue,
      let label = accessibility["label"]?.stringValue
    {
      return label
    }
    return textContent
  }
}
