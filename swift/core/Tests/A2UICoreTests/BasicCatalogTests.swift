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
import Testing

// MARK: - Basic Catalog Tests

struct BasicCatalogTests {

  @Test func allEighteenComponentsAreDefined() {
    let catalog = BasicCatalog.v091Catalog
    #expect(catalog.components.count == 18)

    let names = Set(catalog.components.keys)
    let expected: Set<String> = [
      "Text", "Image", "Icon", "Video", "AudioPlayer",
      "Row", "Column", "List", "Card", "Tabs", "Modal", "Divider",
      "Button", "TextField", "CheckBox", "ChoicePicker", "Slider", "DateTimeInput",
    ]
    #expect(names == expected)
  }

  @Test func canonicalCatalogURIsAreRegistered() {
    #expect(BasicCatalog.allCatalogs[BasicCatalog.v09CatalogURI] != nil)
    #expect(BasicCatalog.allCatalogs[BasicCatalog.v091CatalogURI] != nil)
    #expect(BasicCatalog.allCatalogs[BasicCatalog.v10CatalogURI] != nil)
  }

  @MainActor
  @Test func formattedTextExampleLiveUpdates() throws {
    let processor = MessageProcessor(catalogs: BasicCatalog.allCatalogs)
    try processor.process(line: """
      {"version": "v0.9", "createSurface": {"surfaceId": "gallery-formatted-text", "catalogId": "https://a2ui.org/specification/v0_9/catalogs/basic/catalog.json", "sendDataModel": true}}
      """)
    try processor.process(line: """
      {"version": "v0.9", "updateComponents": {"surfaceId": "gallery-formatted-text", "components": [
        {"id": "root", "component": "Column", "children": ["input_field", "result_label", "result_text"]},
        {"id": "input_field", "component": "TextField", "label": "Type something:", "value": {"path": "/inputValue"}},
        {"id": "result_label", "component": "Text", "text": "Formatted output:"},
        {"id": "result_text", "component": "Text", "text": {"call": "formatString", "args": {"value": "You typed: ${\\/inputValue}"}, "returnType": "string"}}
      ]}}
      """)

    guard let surface = processor.getSurface(id: "gallery-formatted-text") else {
      Issue.record("Surface not found")
      return
    }

    // Initial state before typing:
    let root = surface.rootNode
    guard let columnChildren = root?.properties["children"] as? [Node],
          let resultTextNode = columnChildren.first(where: { $0.id == "result_text" }),
          let binding = resultTextNode.properties["text"] as? DataBinding<String> else {
      Issue.record("result_text node or text binding not found")
      return
    }
    #expect(binding.get() == "You typed: ")

    // Now type "Boop" in the text field:
    surface.dataModel.set("/inputValue", value: .string("Boop"))
    #expect(binding.get() == "You typed: Boop")

    // Check after tree rebuilds
    let updatedRoot = surface.rootNode
    guard let updatedChildren = updatedRoot?.properties["children"] as? [Node],
          let updatedResultTextNode = updatedChildren.first(where: { $0.id == "result_text" }),
          let updatedBinding = updatedResultTextNode.properties["text"] as? DataBinding<String> else {
      Issue.record("updated result_text node or text binding not found")
      return
    }
    #expect(updatedBinding.get() == "You typed: Boop")
  }

  @MainActor
  @Test func flightStatusExampleRendersFullDataModel() throws {
    let processor = MessageProcessor(catalogs: BasicCatalog.allCatalogs)
    try processor.process(line: """
      {"version": "v0.9", "createSurface": {"surfaceId": "gallery-flight-status", "catalogId": "https://a2ui.org/specification/v0_9/catalogs/basic/catalog.json", "sendDataModel": true}}
      """)
    try processor.process(line: """
      {"version": "v0.9", "updateComponents": {"surfaceId": "gallery-flight-status", "components": [
        {"id": "root", "component": "Card", "child": "main-column"},
        {"id": "main-column", "component": "Column", "children": ["header-row", "route-row", "divider", "times-row"], "align": "stretch"},
        {"id": "header-row", "component": "Row", "children": ["flight-number", "date"], "justify": "spaceBetween", "align": "center"},
        {"id": "flight-number", "component": "Text", "text": {"path": "/flightNumber"}, "variant": "h3"},
        {"id": "date", "component": "Text", "text": {"call": "formatDate", "args": {"value": {"path": "/date"}, "format": "E, MMM d"}, "returnType": "string"}, "variant": "caption"},
        {"id": "route-row", "component": "Row", "children": ["origin", "destination"], "align": "center"},
        {"id": "origin", "component": "Text", "text": {"path": "/origin"}, "variant": "h2"},
        {"id": "destination", "component": "Text", "text": {"path": "/destination"}, "variant": "h2"},
        {"id": "divider", "component": "Divider"},
        {"id": "times-row", "component": "Row", "children": ["status-value"], "justify": "spaceBetween"},
        {"id": "status-value", "component": "Text", "text": {"path": "/status"}, "variant": "body"}
      ]}}
      """)
    try processor.process(line: """
      {"version": "v0.9", "updateDataModel": {"surfaceId": "gallery-flight-status", "value": {
        "flightNumber": "OS 87",
        "date": "2025-12-15",
        "origin": "Vienna",
        "destination": "New York",
        "departureTime": "2025-12-15T10:15:00Z",
        "status": "On Time",
        "arrivalTime": "2025-12-15T14:30:00Z"
      }}}
      """)

    guard let surface = processor.getSurface(id: "gallery-flight-status") else {
      Issue.record("Surface not found")
      return
    }

    #expect(surface.dataModel.get("/flightNumber")?.stringValue == "OS 87")
    #expect(surface.dataModel.get("/origin")?.stringValue == "Vienna")
    #expect(surface.dataModel.get("/destination")?.stringValue == "New York")
    #expect(surface.dataModel.get("/status")?.stringValue == "On Time")

    let root = surface.rootNode
    guard let cardChild = root?.properties["child"] as? Node,
          let colChildren = cardChild.properties["children"] as? [Node],
          let headerRow = colChildren.first(where: { $0.id == "header-row" }),
          let headerChildren = headerRow.properties["children"] as? [Node],
          let flightNumberNode = headerChildren.first(where: { $0.id == "flight-number" }),
          let flightNumberBinding = flightNumberNode.properties["text"] as? DataBinding<String>,
          let dateNode = headerChildren.first(where: { $0.id == "date" }),
          let dateBinding = dateNode.properties["text"] as? DataBinding<String> else {
      Issue.record("Failed to resolve flight status node tree")
      return
    }

    #expect(flightNumberBinding.get() == "OS 87")
    #expect(dateBinding.get() == "Mon, Dec 15")
  }
}
