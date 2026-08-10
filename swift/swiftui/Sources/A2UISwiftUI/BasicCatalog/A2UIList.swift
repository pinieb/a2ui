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

/// SwiftUI component view for the A2UI Basic Catalog `List` scrollable container component.
public struct A2UIList: View {
  public let node: Node

  public init(node: Node) {
    self.node = node
  }

  private var children: [Node] {
    (node.properties["children"] as? [Node]) ?? []
  }

  private var direction: String {
    node.properties["direction"] as? String ?? "vertical"
  }

  public var body: some View {
    if direction == "horizontal" {
      ScrollView(.horizontal, showsIndicators: false) {
        LazyHStack(spacing: 12) {
          ForEach(children) { childNode in
            ComponentNodeView(node: childNode)
          }
        }
        .padding(.horizontal, 4)
      }
    } else {
      ScrollView(.vertical, showsIndicators: true) {
        LazyVStack(alignment: .leading, spacing: 12) {
          ForEach(children) { childNode in
            ComponentNodeView(node: childNode)
          }
        }
        .padding(.vertical, 4)
      }
    }
  }
}
