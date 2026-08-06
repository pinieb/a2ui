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

/// SwiftUI component view for the A2UI Basic Catalog `DateTimeInput` component.
public struct A2UIDateTimeInput: View {
  public let node: Node

  @State private var internalDate: Date = Date()

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

  private var enableDate: Bool {
    if let b = node.properties["enableDate"] as? Bool {
      return b
    }
    if let json = node.properties["enableDate"] as? JSONValue {
      return json.boolValue ?? false
    }
    return false
  }

  private var enableTime: Bool {
    if let b = node.properties["enableTime"] as? Bool {
      return b
    }
    if let json = node.properties["enableTime"] as? JSONValue {
      return json.boolValue ?? false
    }
    return false
  }

  private var displayedComponents: DatePickerComponents {
    if enableDate && enableTime {
      return [.date, .hourAndMinute]
    } else if enableTime {
      return [.hourAndMinute]
    } else {
      return [.date]
    }
  }

  private var dateBinding: Binding<Date> {
    Binding(
      get: {
        if let dataBinding = node.properties["value"] as? DataBinding<String> {
          let dateStr = dataBinding.get()
          if let parsed = parseISO8601(dateStr) {
            return parsed
          }
        }
        return internalDate
      },
      set: { newDate in
        internalDate = newDate
        if let dataBinding = node.properties["value"] as? DataBinding<String> {
          dataBinding.set(formatISO8601(newDate))
        }
      }
    )
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      if !labelText.isEmpty {
        Text(labelText)
          .font(.subheadline.weight(.medium))
          .foregroundStyle(.secondary)
      }

      DatePicker(
        "",
        selection: dateBinding,
        displayedComponents: displayedComponents
      )
      .labelsHidden()
      .padding(8)
      .background(Color.gray.opacity(0.12))
      .cornerRadius(8)
    }
  }

  private func parseISO8601(_ string: String) -> Date? {
    guard !string.isEmpty else { return nil }
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter.date(from: string) ?? ISO8601DateFormatter().date(from: string)
  }

  private func formatISO8601(_ date: Date) -> String {
    let formatter = ISO8601DateFormatter()
    return formatter.string(from: date)
  }
}
