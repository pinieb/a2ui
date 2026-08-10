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

/// SwiftUI component view for the A2UI Basic Catalog `TextField` input component.
public struct A2UITextField: View {
  public let node: Node

  @State private var fallbackText = ""

  public init(node: Node) {
    self.node = node
  }

  private var labelText: String {
    (node.properties["label"] as? DataBinding<String>)?.get() ?? ""
  }

  private var variant: String {
    node.properties["variant"] as? String ?? "shortText"
  }

  private var valueBinding: Binding<String> {
    if let dataBinding = node.properties["value"] as? DataBinding<String> {
      return dataBinding.swiftUIBinding
    }
    return $fallbackText
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      if !labelText.isEmpty {
        Text(labelText)
          .font(.subheadline.weight(.medium))
          .foregroundStyle(.secondary)
      }

      inputFieldForVariant
        .padding(10)
        .background(Color.gray.opacity(0.12))
        .cornerRadius(8)
        .overlay(
          RoundedRectangle(cornerRadius: 8)
            .stroke(Color.primary.opacity(0.1), lineWidth: 1)
        )
    }
  }

  @ViewBuilder
  private var inputFieldForVariant: some View {
    switch variant {
    case "obscured":
      SecureField(labelText, text: valueBinding)
    case "longText":
      TextEditor(text: valueBinding)
        .frame(minHeight: 80)
    case "number":
      #if os(iOS)
        TextField(labelText, text: valueBinding)
          .keyboardType(.decimalPad)
      #else
        TextField(labelText, text: valueBinding)
      #endif
    default:
      TextField(labelText, text: valueBinding)
    }
  }
}
