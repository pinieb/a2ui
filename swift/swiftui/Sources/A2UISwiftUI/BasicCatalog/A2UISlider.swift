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

/// SwiftUI component view for the A2UI Basic Catalog `Slider` range input component.
public struct A2UISlider: View {
  public let node: Node

  @State private var fallbackValue: Double = 0

  public init(node: Node) {
    self.node = node
  }

  private var labelText: String {
    if let binding = node.properties["label"] as? DataBinding<String> {
      return binding.get()
    }
    if let str = node.properties["label"] as? String {
      return str
    }
    if let json = node.properties["label"] as? JSONValue {
      return json.stringValue ?? ""
    }
    return ""
  }

  private var minValue: Double {
    if let m = node.properties["min"] as? Double {
      return m
    }
    if let json = node.properties["min"] as? JSONValue {
      return json.doubleValue ?? 0
    }
    return 0
  }

  private var maxValue: Double {
    if let m = node.properties["max"] as? Double {
      return m
    }
    if let json = node.properties["max"] as? JSONValue {
      return json.doubleValue ?? 100
    }
    return 100
  }

  private var sliderBinding: Binding<Double> {
    if let dataBinding = node.properties["value"] as? DataBinding<Double> {
      return dataBinding.swiftUIBinding
    }
    return $fallbackValue
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack {
        if !labelText.isEmpty {
          Text(labelText)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.secondary)
        }
        Spacer()
        Text(String(format: "%.1f", sliderBinding.wrappedValue))
          .font(.subheadline.monospacedDigit())
          .foregroundStyle(.secondary)
      }

      Slider(
        value: sliderBinding,
        in: minValue...max(minValue + 0.001, maxValue)
      )
    }
  }
}
