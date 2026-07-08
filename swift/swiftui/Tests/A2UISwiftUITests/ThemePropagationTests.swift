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
import A2UIJSON
import A2UISwiftUI
import JSONSchema
import OrderedJSON
import SwiftUI
import Testing

// MARK: - Test Types

/// A concrete theme for testing theme propagation.
struct ThemePropagationTheme: SurfaceTheme {
  let primaryColor: String
  let fontSize: Double
}

/// A catalog that produces themes for propagation tests.
struct ThemePropagationCatalog: ComponentCatalog {
  let textSchema: Schema

  init() throws {
    textSchema = try Schema(
      instance: """
        {
          "type": "object",
          "properties": {
            "id": {"type": "string"},
            "component": {"type": "string"},
            "text": {"$ref": "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/DynamicString"}
          },
          "required": ["id", "component"]
        }
        """,
      remoteSchemas: A2UICommonSchema.allSchemas
    )
  }

  func schema(forType type: String) -> Schema? {
    switch type {
    case "text": return textSchema
    default: return nil
    }
  }

  func makeTheme(jsonObject: JSONValue) -> (any SurfaceTheme)? {
    guard let dict = jsonObject.dictionaryValue else { return nil }
    return ThemePropagationTheme(
      primaryColor: dict["primaryColor"]?.stringValue ?? "black",
      fontSize: dict["fontSize"]?.doubleValue ?? 14.0
    )
  }

  func localFunction(for name: String) -> (any LocalFunction)? {
    nil
  }
}

/// A catalog view that reads the theme from the environment.
struct ThemeReadingCatalogView: CatalogView {
  let node: Node
  @Environment(\.a2uiTheme) private var theme

  init(node: Node) {
    self.node = node
  }

  var body: some View {
    Text(node.id)
  }
}

// MARK: - Theme Propagation Tests

struct ThemePropagationTests {

  // MARK: - Theme Key

  @Test func themeKeyDefaultValueIsNil() {
    #expect(A2UIThemeKey.defaultValue == nil)
  }

  @Test func themeEnvironmentStoresAndRetrievesTheme() {
    let theme = ThemePropagationTheme(primaryColor: "red", fontSize: 18.0)
    var env = EnvironmentValues()
    env.a2uiTheme = theme

    let retrieved = env.a2uiTheme
    #expect(retrieved != nil)
    #expect((retrieved as? ThemePropagationTheme)?.primaryColor == "red")
    #expect((retrieved as? ThemePropagationTheme)?.fontSize == 18.0)
  }

  @Test func themeEnvironmentCanSetNil() {
    var env = EnvironmentValues()
    env.a2uiTheme = ThemePropagationTheme(primaryColor: "blue", fontSize: 12.0)
    env.a2uiTheme = nil
    #expect(env.a2uiTheme == nil)
  }

  // MARK: - SurfaceViewModel Theme Management

  @Test func surfaceViewModelStoresActiveTheme() throws {
    let catalog = try ThemePropagationCatalog()
    let vm = SurfaceViewModel(surfaceID: "s1", catalog: catalog)
    let theme = ThemePropagationTheme(primaryColor: "green", fontSize: 16.0)

    vm.updateTheme(theme)

    let active = vm.getActiveTheme()
    #expect(active != nil)
    #expect((active as? ThemePropagationTheme)?.primaryColor == "green")
  }

  @Test func surfaceViewModelThemeIsNilBeforeUpdate() throws {
    let catalog = try ThemePropagationCatalog()
    let vm = SurfaceViewModel(surfaceID: "s1", catalog: catalog)

    #expect(vm.getActiveTheme() == nil)
  }

  // MARK: - Message Processor Theme Creation

  @Test func messageProcessorCreatesThemeFromCreateSurface() throws {
    let catalog = try ThemePropagationCatalog()
    let handler = IntegrationActionHandler()
    let processor = MessageProcessor(
      catalogs: ["default": catalog],
      actionHandler: handler
    )

    try processor.process(line: """
      {"createSurface": {"surfaceId": "s1", "catalogId": "default", "theme": {"primaryColor": "purple", "fontSize": 20.0}}}
      """)

    let vm = processor.getSurface(id: "s1")
    let theme = vm?.getActiveTheme() as? ThemePropagationTheme
    #expect(theme != nil)
    #expect(theme?.primaryColor == "purple")
    #expect(theme?.fontSize == 20.0)
  }

  @Test func messageProcessorHandlesMissingThemeGracefully() throws {
    let catalog = try ThemePropagationCatalog()
    let processor = MessageProcessor(
      catalogs: ["default": catalog]
    )

    try processor.process(line: """
      {"createSurface": {"surfaceId": "s1", "catalogId": "default"}}
      """)

    let vm = processor.getSurface(id: "s1")
    #expect(vm?.getActiveTheme() == nil)
  }

  @Test func catalogMakeThemeReturnsNilForInvalidJSON() throws {
    let catalog = try ThemePropagationCatalog()
    #expect(catalog.makeTheme(jsonObject: "not an object") == nil)
    #expect(catalog.makeTheme(jsonObject: 42) == nil)
    #expect(catalog.makeTheme(jsonObject: .null) == nil)
  }

  @Test func catalogMakeThemeUsesDefaultsForMissingKeys() throws {
    let catalog = try ThemePropagationCatalog()
    let theme = catalog.makeTheme(jsonObject: .object([:])) as? ThemePropagationTheme
    #expect(theme?.primaryColor == "black")
    #expect(theme?.fontSize == 14.0)
  }

  // MARK: - Theme Update Triggers Rebuild

  @Test func updatingThemeDoesNotCrashWithoutComponents() throws {
    let catalog = try ThemePropagationCatalog()
    let vm = SurfaceViewModel(surfaceID: "s1", catalog: catalog)

    vm.updateTheme(ThemePropagationTheme(primaryColor: "orange", fontSize: 16.0))
    // Should not crash even with no components
    #expect(vm.getActiveTheme() != nil)
  }
}
