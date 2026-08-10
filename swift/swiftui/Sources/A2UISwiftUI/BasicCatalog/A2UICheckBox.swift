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

/// SwiftUI component view for the A2UI Basic Catalog `CheckBox` component.
public struct A2UICheckBox: View {
  public let node: Node

  @State private var fallbackBool = false

  public init(node: Node) {
    self.node = node
  }

  private var labelText: String {
    (node.properties["label"] as? DataBinding<String>)?.get() ?? ""
  }

  private var boolBinding: Binding<Bool> {
    if let dataBinding = node.properties["value"] as? DataBinding<Bool> {
      return dataBinding.swiftUIBinding
    }
    return $fallbackBool
  }

  public var body: some View {
    Toggle(isOn: boolBinding) {
      Text(labelText)
        .font(.body)
    }
    .toggleStyle(.checkboxStyle)
  }
}

// Custom Checkbox ToggleStyle for platform consistency
private struct CheckboxToggleStyle: ToggleStyle {
  func makeBody(configuration: Configuration) -> some View {
    Button(action: { configuration.isOn.toggle() }) {
      HStack(spacing: 10) {
        Image(systemName: configuration.isOn ? "checkmark.square.fill" : "square")
          .font(.system(size: 20))
          .foregroundStyle(configuration.isOn ? Color.accentColor : Color.secondary)

        configuration.label
          .foregroundStyle(Color.primary)
      }
    }
    .buttonStyle(.plain)
  }
}

extension ToggleStyle where Self == CheckboxToggleStyle {
  fileprivate static var checkboxStyle: CheckboxToggleStyle {
    CheckboxToggleStyle()
  }
}
