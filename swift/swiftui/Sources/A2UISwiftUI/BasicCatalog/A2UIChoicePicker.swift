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

/// SwiftUI component view for the A2UI Basic Catalog `ChoicePicker` selection component.
public struct A2UIChoicePicker: View {
  public let node: Node

  @State private var filterText = ""
  @State private var fallbackSelections: [String] = []

  public init(node: Node) {
    self.node = node
  }

  public struct OptionItem: Identifiable, Equatable {
    public let id: String
    public let label: String
    public let value: String
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

  private var variant: String {
    if let v = node.properties["variant"] as? String {
      return v
    }
    if let json = node.properties["variant"] as? JSONValue {
      return json.stringValue ?? "mutuallyExclusive"
    }
    return "mutuallyExclusive"
  }

  private var displayStyle: String {
    if let d = node.properties["displayStyle"] as? String {
      return d
    }
    if let json = node.properties["displayStyle"] as? JSONValue {
      return json.stringValue ?? "checkbox"
    }
    return "checkbox"
  }

  private var isFilterable: Bool {
    if let b = node.properties["filterable"] as? Bool {
      return b
    }
    if let json = node.properties["filterable"] as? JSONValue {
      return json.boolValue ?? false
    }
    return false
  }

  private var options: [OptionItem] {
    if let json = node.properties["options"] as? JSONValue, let array = json.arrayValue {
      return array.enumerated().map { index, item in
        let optLabel = item["label"]?.stringValue ?? "Option \(index + 1)"
        let optVal = item["value"]?.stringValue ?? "\(index)"
        return OptionItem(id: optVal, label: optLabel, value: optVal)
      }
    }
    return []
  }

  private var filteredOptions: [OptionItem] {
    if filterText.isEmpty {
      return options
    }
    return options.filter { $0.label.localizedCaseInsensitiveContains(filterText) }
  }

  private var selectedValues: [String] {
    if let binding = node.properties["value"] as? DataBinding<[String]> {
      return binding.get()
    }
    if let binding = node.properties["value"] as? DataBinding<JSONValue> {
      return binding.get().arrayValue?.compactMap { $0.stringValue } ?? []
    }
    if let json = node.properties["value"] as? JSONValue, let arr = json.arrayValue {
      return arr.compactMap { $0.stringValue }
    }
    return fallbackSelections
  }

  private func toggleSelection(_ optionVal: String) {
    var current = selectedValues
    if variant == "mutuallyExclusive" {
      current = [optionVal]
    } else {
      if let idx = current.firstIndex(of: optionVal) {
        current.remove(at: idx)
      } else {
        current.append(optionVal)
      }
    }

    if let binding = node.properties["value"] as? DataBinding<[String]> {
      binding.set(current)
    } else if let binding = node.properties["value"] as? DataBinding<JSONValue> {
      binding.set(.array(current.map { .string($0) }))
    } else {
      fallbackSelections = current
    }
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      if !labelText.isEmpty {
        Text(labelText)
          .font(.subheadline.weight(.medium))
          .foregroundStyle(.secondary)
      }

      if isFilterable {
        HStack {
          Image(systemName: "magnifyingglass")
            .foregroundStyle(.secondary)
          TextField("Search options", text: $filterText)
        }
        .padding(8)
        .background(Color.gray.opacity(0.12))
        .cornerRadius(8)
      }

      if displayStyle == "chips" {
        chipsView
      } else {
        checkboxListView
      }
    }
  }

  @ViewBuilder
  private var chipsView: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 8) {
        ForEach(filteredOptions, id: \.id) { option in
          let isSelected = selectedValues.contains(option.value)
          Button(action: { toggleSelection(option.value) }) {
            Text(option.label)
              .font(.subheadline)
              .padding(.horizontal, 14)
              .padding(.vertical, 8)
              .background(isSelected ? Color.accentColor : Color.gray.opacity(0.12))
              .foregroundStyle(isSelected ? Color.white : Color.primary)
              .clipShape(Capsule())
              .overlay(
                Capsule()
                  .stroke(Color.primary.opacity(0.1), lineWidth: isSelected ? 0 : 1)
              )
          }
          .buttonStyle(.plain)
        }
      }
    }
  }

  @ViewBuilder
  private var checkboxListView: some View {
    VStack(alignment: .leading, spacing: 8) {
      ForEach(filteredOptions, id: \.id) { option in
        let isSelected = selectedValues.contains(option.value)
        Button(action: { toggleSelection(option.value) }) {
          HStack(spacing: 10) {
            Image(
              systemName: variant == "mutuallyExclusive"
                ? (isSelected ? "largecircle.fill.circle" : "circle")
                : (isSelected ? "checkmark.square.fill" : "square")
            )
            .font(.system(size: 18))
            .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)

            Text(option.label)
              .font(.body)
              .foregroundStyle(Color.primary)

            Spacer()
          }
          .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
      }
    }
  }
}
