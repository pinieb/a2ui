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

/// SwiftUI component view for the A2UI Basic Catalog `Row` layout component.
public struct A2UIRow: View {
  public let node: Node

  public init(node: Node) {
    self.node = node
  }

  private var children: [Node] {
    (node.properties["children"] as? [Node]) ?? []
  }

  private var align: String {
    node.properties["align"] as? String ?? "stretch"
  }

  private var justify: String {
    node.properties["justify"] as? String ?? "start"
  }

  public var body: some View {
    HStack(alignment: verticalAlignment, spacing: spacing) {
      if justify == "end" || justify == "center" {
        Spacer(minLength: 0)
      }

      ForEach(Array(children.enumerated()), id: \.element.id) { index, childNode in
        ComponentNodeView(node: childNode)

        if justify == "spaceBetween" && index < children.count - 1 {
          Spacer()
        } else if justify == "spaceAround" || justify == "spaceEvenly" {
          Spacer()
        }
      }

      if justify == "start" || justify == "center" {
        Spacer(minLength: 0)
      }
    }
  }

  private var verticalAlignment: VerticalAlignment {
    switch align {
    case "start": return .top
    case "end": return .bottom
    default: return .center
    }
  }

  private var spacing: CGFloat? {
    if justify == "spaceBetween" || justify == "spaceAround" || justify == "spaceEvenly" {
      return 0
    }
    return 8
  }
}
