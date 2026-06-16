<!--
 Copyright 2026 Google LLC

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

     https://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
-->

# A2UI SwiftUI Renderer

A lightweight, declarative SwiftUI rendering engine for the A2UI protocol. Converts abstract UI
node trees into native, high-performance SwiftUI views with two-way reactive data binding and
dynamic theme propagation.

---

## Target Platforms

* **iOS 16.0+** (`.iOS(.v16)`)
* **macOS 13.0+** (`.macOS(.v13)`)

---

## Integration

The SwiftUI renderer is part of the `A2UISwiftCore` package. To integrate it, add it to your
`Package.swift` dependencies:

```swift
dependencies: [
  .package(name: "A2UISwiftCore", path: "path/to/a2ui")
]
```

Then add the `A2UISwiftUI` product to your target's dependencies:

```swift
targets: [
  .target(
    name: "MySwiftUITarget",
    dependencies: [
      .product(name: "A2UISwiftUI", package: "A2UISwiftCore")
    ]
  )
]
```

---

## Quick Start Example

### 1. Define your Component Catalog

Create a catalog that implements both `ComponentCatalog` (for schema validation) and `CatalogView`
(for SwiftUI view resolution):

```swift
import A2UICore
import A2UISwiftUI
import JSONSchema
import SwiftUI

// 1. Define the ComponentCatalog to provide schemas to the engine
struct MyComponentCatalog: ComponentCatalog {
  func schema(forType type: String) -> JSONSchema? {
    // Return appropriate JSONSchema for validation
    return nil
  }

  func makeTheme(jsonObject: JSONValue) -> (any SurfaceTheme)? {
    return nil
  }

  func localFunction(for name: String) -> (any LocalFunction)? {
    return nil
  }
}

// 2. Define the CatalogView to draw the SwiftUI hierarchy
struct MyCatalogView: CatalogView {
  let node: Node

  init(node: Node) {
    self.node = node
  }

  var body: some View {
    switch node.type {
    case "Text":
      let textBinding = node.properties["text"] as? DataBinding<String>
      Text(textBinding?.get() ?? "")
    case "VStack":
      let children = node.properties["children"] as? [Node] ?? []
      VStack {
        ForEach(children) { child in
          MyCatalogView(node: child)
        }
      }
    default:
      Text("Unknown: \(node.type)")
    }
  }
}
```

### 2. Render the Surface View

Use the `Surface` view in your SwiftUI hierarchy, passing the stateful `SurfaceViewModel` and your catalog view type:

```swift
import A2UICore
import A2UISwiftUI
import SwiftUI

struct MainView: View {
  @StateObject private var viewModel = SurfaceViewModel(
    surfaceID: "surface_1",
    catalog: MyComponentCatalog()
  )

  var body: some View {
    Surface(viewModel: viewModel, catalogType: MyCatalogView.self)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}
```

---

## Next Steps

* For a deep dive into view hierarchy, environment keys, and reactive bindings, see
  [ARCHITECTURE.md](ARCHITECTURE.md).
* For build, test, and formatting instructions, see
  [DEVELOPMENT.md](DEVELOPMENT.md).
* For AI agent rules of engagement, see
  [AGENTS.md](AGENTS.md).
