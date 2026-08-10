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

  @MainActor
  @Test func childListTemplateExpansionRendersItemsWithBoundValues() throws {
    let processor = MessageProcessor(catalogs: BasicCatalog.allCatalogs)
    try processor.process(line: """
      {"version": "v0.9", "createSurface": {"surfaceId": "gallery-child-list-template", "catalogId": "https://a2ui.org/specification/v0_9/catalogs/basic/catalog.json", "sendDataModel": true}}
      """)
    try processor.process(line: """
      {"version": "v0.9", "updateComponents": {"surfaceId": "gallery-child-list-template", "components": [
        {"id": "root", "component": "Card", "child": "main-column"},
        {"id": "main-column", "component": "Column", "children": ["title-text", "item-list"], "align": "stretch"},
        {"id": "title-text", "component": "Text", "text": "Dynamic Item List", "variant": "h3"},
        {"id": "item-list", "component": "List", "children": {"componentId": "item-row", "path": "/items"}},
        {"id": "item-row", "component": "Row", "children": ["item-name", "qty-label", "item-qty"]},
        {"id": "item-name", "component": "Text", "text": {"path": "name"}},
        {"id": "qty-label", "component": "Text", "text": " - Qty: "},
        {"id": "item-qty", "component": "Text", "text": {"path": "quantity"}}
      ]}}
      """)
    try processor.process(line: """
      {"version": "v0.9", "updateDataModel": {"surfaceId": "gallery-child-list-template", "value": {
        "items": [
          {"name": "Apple", "quantity": 10},
          {"name": "Banana", "quantity": 5},
          {"name": "Cherry", "quantity": 20}
        ]
      }}}
      """)

    guard let surface = processor.getSurface(id: "gallery-child-list-template") else {
      Issue.record("Surface not found")
      return
    }

    let root = surface.rootNode
    guard let cardChild = root?.properties["child"] as? Node,
          let colChildren = cardChild.properties["children"] as? [Node],
          let listNode = colChildren.first(where: { $0.id == "item-list" }),
          let listChildren = listNode.properties["children"] as? [Node] else {
      Issue.record("Failed to resolve list node tree")
      return
    }

    #expect(listChildren.count == 3)

    // Check item 0 (Apple - Qty: 10)
    let row0 = listChildren[0]
    #expect(row0.id == "item-row_0")
    guard let row0Children = row0.properties["children"] as? [Node],
          let name0 = (row0Children.first(where: { $0.id == "item-name" })?.properties["text"] as? DataBinding<String>)?.get(),
          let qtyLabel0 = (row0Children.first(where: { $0.id == "qty-label" })?.properties["text"] as? DataBinding<String>)?.get(),
          let qty0 = (row0Children.first(where: { $0.id == "item-qty" })?.properties["text"] as? DataBinding<String>)?.get() else {
      Issue.record("Row 0 children not found")
      return
    }
    #expect(name0 == "Apple")
    #expect(qtyLabel0 == " - Qty: ")
    #expect(qty0 == "10")

    // Check item 1 (Banana - Qty: 5)
    let row1 = listChildren[1]
    #expect(row1.id == "item-row_1")
    guard let row1Children = row1.properties["children"] as? [Node],
          let name1 = (row1Children.first(where: { $0.id == "item-name" })?.properties["text"] as? DataBinding<String>)?.get(),
          let qty1 = (row1Children.first(where: { $0.id == "item-qty" })?.properties["text"] as? DataBinding<String>)?.get() else {
      Issue.record("Row 1 children not found")
      return
    }
    #expect(name1 == "Banana")
    #expect(qty1 == "5")

    // Check item 2 (Cherry - Qty: 20)
    let row2 = listChildren[2]
    #expect(row2.id == "item-row_2")
    guard let row2Children = row2.properties["children"] as? [Node],
          let name2 = (row2Children.first(where: { $0.id == "item-name" })?.properties["text"] as? DataBinding<String>)?.get(),
          let qty2 = (row2Children.first(where: { $0.id == "item-qty" })?.properties["text"] as? DataBinding<String>)?.get() else {
      Issue.record("Row 2 children not found")
      return
    }
    #expect(name2 == "Cherry")
    #expect(qty2 == "20")
  }
}
