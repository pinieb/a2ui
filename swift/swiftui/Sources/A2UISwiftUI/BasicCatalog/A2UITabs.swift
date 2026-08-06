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

/// SwiftUI component view for the A2UI Basic Catalog `Tabs` component.
public struct A2UITabs: View {
  public let node: Node

  @State private var selectedIndex = 0

  public init(node: Node) {
    self.node = node
  }

  private struct TabData: Identifiable {
    let id: Int
    let title: String
    let childNode: Node?
  }

  private var tabs: [TabData] {
    if let json = node.properties["tabs"] as? JSONValue, let array = json.arrayValue {
      return array.enumerated().map { index, item in
        let title = item["title"]?.stringValue ?? "Tab \(index + 1)"
        // If child is already a node or string
        let childID = item["child"]?.stringValue ?? ""
        // Look up child in allChildNodes if matching
        let child = node.allChildNodes.first { $0.id == childID }
        return TabData(id: index, title: title, childNode: child)
      }
    }
    return []
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      // Tab Bar Headers
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 8) {
          ForEach(tabs) { tab in
            Button(action: { selectedIndex = tab.id }) {
              Text(tab.title)
                .font(.subheadline.weight(selectedIndex == tab.id ? .semibold : .regular))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                  selectedIndex == tab.id
                    ? Color.accentColor.opacity(0.12)
                    : Color.clear
                )
                .foregroundStyle(
                  selectedIndex == tab.id
                    ? Color.accentColor
                    : Color.secondary
                )
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
          }
        }
      }

      Divider()

      // Selected Tab Content
      if selectedIndex < tabs.count, let childNode = tabs[selectedIndex].childNode {
        ComponentNodeView(node: childNode)
      }
    }
  }
}
