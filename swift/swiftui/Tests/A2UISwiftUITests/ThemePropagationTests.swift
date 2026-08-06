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

// MARK: - Theme Propagation Tests

@MainActor
struct ThemePropagationTests {

  // MARK: - Theme Key

  @Test func themeKeyDefaultValueIsNil() {
    #expect(A2UIThemeKey.defaultValue == nil)
  }

  @Test func themeEnvironmentStoresAndRetrievesTheme() {
    let theme: [String: JSONValue] = [
      "primaryColor": .string("#FF0000"),
      "fontSize": .number(18.0),
    ]
    var env = EnvironmentValues()
    env.a2uiTheme = theme

    let retrieved = env.a2uiTheme
    #expect(retrieved != nil)
    #expect(retrieved?["primaryColor"]?.stringValue == "#FF0000")
    #expect(retrieved?["fontSize"]?.doubleValue == 18.0)
  }

  @Test func themeEnvironmentCanSetNil() {
    var env = EnvironmentValues()
    env.a2uiTheme = ["primaryColor": .string("#0000FF")]
    env.a2uiTheme = nil
    #expect(env.a2uiTheme == nil)
  }

  // MARK: - SurfaceViewModel Theme Management

  @Test func surfaceViewModelStoresActiveTheme() throws {
    let catalog = BasicCatalog.v091Catalog
    let vm = SurfaceViewModel(surfaceID: "s1", catalogs: [catalog.id: catalog])
    let theme: [String: JSONValue] = ["primaryColor": .string("#00FF00")]

    vm.updateTheme(theme)

    let active = vm.theme
    #expect(active != nil)
    #expect(active?["primaryColor"]?.stringValue == "#00FF00")
  }

  @Test func surfaceViewModelThemeIsNilBeforeUpdate() throws {
    let catalog = BasicCatalog.v091Catalog
    let vm = SurfaceViewModel(surfaceID: "s1", catalogs: [catalog.id: catalog])

    #expect(vm.theme == nil)
  }

  // MARK: - Message Processor Theme Creation

  @Test func messageProcessorCreatesThemeFromCreateSurface() throws {
    let catalog = BasicCatalog.v091Catalog
    let processor = MessageProcessor(
      catalogs: [catalog.id: catalog]
    )

    try processor.process(line: """
      {"version": "v0.9.1", "createSurface": {"surfaceId": "s1", "catalogId": "\(catalog.id)", "theme": {"primaryColor": "#800080"}}}
      """)

    let vm = processor.getSurface(id: "s1")
    let theme = vm?.theme
    #expect(theme != nil)
    #expect(theme?["primaryColor"]?.stringValue == "#800080")
  }

  @Test func messageProcessorHandlesMissingThemeGracefully() throws {
    let catalog = BasicCatalog.v091Catalog
    let processor = MessageProcessor(
      catalogs: [catalog.id: catalog]
    )

    try processor.process(line: """
      {"version": "v0.9.1", "createSurface": {"surfaceId": "s1", "catalogId": "\(catalog.id)"}}
      """)

    let vm = processor.getSurface(id: "s1")
    #expect(vm?.theme == nil)
  }
}
