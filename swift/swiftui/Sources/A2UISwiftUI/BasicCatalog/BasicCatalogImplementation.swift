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
import SwiftUI

/// Provides pre-configured SwiftUI component implementations for all 18 basic components.
public enum BasicCatalogImplementation: Sendable {

  /// All 18 concrete component implementations for SwiftUI.
  public static var allComponents: [ComponentImplementation] {
    [
      ComponentImplementation(api: BasicCatalogComponents.text) { node in
        AnyView(A2UIText(node: node))
      },
      ComponentImplementation(api: BasicCatalogComponents.image) { node in
        AnyView(A2UIImage(node: node))
      },
      ComponentImplementation(api: BasicCatalogComponents.icon) { node in
        AnyView(A2UIIcon(node: node))
      },
      ComponentImplementation(api: BasicCatalogComponents.video) { node in
        AnyView(A2UIVideo(node: node))
      },
      ComponentImplementation(api: BasicCatalogComponents.audioPlayer) { node in
        AnyView(A2UIAudioPlayer(node: node))
      },
      ComponentImplementation(api: BasicCatalogComponents.row) { node in
        AnyView(A2UIRow(node: node))
      },
      ComponentImplementation(api: BasicCatalogComponents.column) { node in
        AnyView(A2UIColumn(node: node))
      },
      ComponentImplementation(api: BasicCatalogComponents.list) { node in
        AnyView(A2UIList(node: node))
      },
      ComponentImplementation(api: BasicCatalogComponents.card) { node in
        AnyView(A2UICard(node: node))
      },
      ComponentImplementation(api: BasicCatalogComponents.tabs) { node in
        AnyView(A2UITabs(node: node))
      },
      ComponentImplementation(api: BasicCatalogComponents.modal) { node in
        AnyView(A2UIModal(node: node))
      },
      ComponentImplementation(api: BasicCatalogComponents.divider) { node in
        AnyView(A2UIDivider(node: node))
      },
      ComponentImplementation(api: BasicCatalogComponents.button) { node in
        AnyView(A2UIButton(node: node))
      },
      ComponentImplementation(api: BasicCatalogComponents.textField) { node in
        AnyView(A2UITextField(node: node))
      },
      ComponentImplementation(api: BasicCatalogComponents.checkBox) { node in
        AnyView(A2UICheckBox(node: node))
      },
      ComponentImplementation(api: BasicCatalogComponents.choicePicker) { node in
        AnyView(A2UIChoicePicker(node: node))
      },
      ComponentImplementation(api: BasicCatalogComponents.slider) { node in
        AnyView(A2UISlider(node: node))
      },
      ComponentImplementation(api: BasicCatalogComponents.dateTimeInput) { node in
        AnyView(A2UIDateTimeInput(node: node))
      },
    ]
  }

  /// Registers all basic components into the given catalog implementation.
  public static func register(
    in catalogImplementation: CatalogImplementation,
    catalogID: String? = nil
  ) {
    catalogImplementation.register(
      catalogID: catalogID,
      components: allComponents
    )
  }

  /// Registers all basic components for a specific catalog definition.
  public static func register(
    in catalogImplementation: CatalogImplementation,
    catalog: Catalog
  ) {
    catalogImplementation.register(
      catalog: catalog,
      components: allComponents
    )
  }
}

extension CatalogImplementation {
  /// Creates a `CatalogImplementation` populated with all 18 Basic Catalog SwiftUI component implementations.
  public static func basic(catalog: Catalog = BasicCatalog.v091Catalog) -> CatalogImplementation {
    let impl = CatalogImplementation()
    // Register without catalog ID for universal unqualified fallback
    BasicCatalogImplementation.register(in: impl, catalogID: nil)
    // Also register explicitly under canonical catalog URIs
    BasicCatalogImplementation.register(in: impl, catalogID: BasicCatalog.v09CatalogURI)
    BasicCatalogImplementation.register(in: impl, catalogID: BasicCatalog.v091CatalogURI)
    BasicCatalogImplementation.register(in: impl, catalogID: BasicCatalog.v10CatalogURI)
    return impl
  }
}
