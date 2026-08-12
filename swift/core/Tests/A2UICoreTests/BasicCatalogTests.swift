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
    try processor.process(
      line: """
        {"version": "v0.9", "createSurface": {"surfaceId": "gallery-formatted-text", "catalogId": "https://a2ui.org/specification/v0_9/catalogs/basic/catalog.json", "sendDataModel": true}}
        """)
    try processor.process(
      line: """
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
      let binding = resultTextNode.properties["text"] as? DataBinding<String>
    else {
      Issue.record("result_text node or text binding not found")
      return
    }
    #expect(binding.value == "You typed: ")

    // Now type "Boop" in the text field:
    surface.dataModel.set("/inputValue", value: .string("Boop"))
    
    // Check after tree rebuilds
    let updatedRoot = surface.rootNode
    guard let updatedChildren = updatedRoot?.properties["children"] as? [Node],
      let updatedResultTextNode = updatedChildren.first(where: { $0.id == "result_text" }),
      let updatedBinding = updatedResultTextNode.properties["text"] as? DataBinding<String>
    else {
      Issue.record("updated result_text node or text binding not found")
      return
    }
    #expect(updatedBinding.value == "You typed: Boop")
  }

  @MainActor
  @Test func flightStatusExampleRendersFullDataModel() throws {
    let processor = MessageProcessor(catalogs: BasicCatalog.allCatalogs)
    try processor.process(
      line: """
        {"version": "v0.9", "createSurface": {"surfaceId": "gallery-flight-status", "catalogId": "https://a2ui.org/specification/v0_9/catalogs/basic/catalog.json", "sendDataModel": true}}
        """)
    try processor.process(
      line: """
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
    try processor.process(
      line: """
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
      let dateBinding = dateNode.properties["text"] as? DataBinding<String>
    else {
      Issue.record("Failed to resolve flight status node tree")
      return
    }

    #expect(flightNumberBinding.value == "OS 87")
    #expect(dateBinding.value == "Mon, Dec 15")
  }

  @MainActor
  @Test func eventDetailExampleRendersFormattedDate() throws {
    let processor = MessageProcessor(catalogs: BasicCatalog.allCatalogs)
    let catalogURI = "https://a2ui.org/specification/v0_9/catalogs/basic/catalog.json"
    let createMsg = """
      {"version": "v0.9", "createSurface": {"surfaceId": "gallery-event-detail", \
      "catalogId": "\(catalogURI)", "sendDataModel": true}}
      """
    try processor.process(line: createMsg)

    let tmpl =
      "${formatDate(value: ${/start}, format: 'E, MMM d')} • "
      + "${formatDate(value: ${/start}, format: 'h:mm a')} - "
      + "${formatDate(value: ${/end}, format: 'h:mm a')}"
    let updateComponentsMsg = """
      {"version": "v0.9", "updateComponents": {"surfaceId": "gallery-event-detail", "components": [
        {"id": "root", "component": "Card", "child": "main-column"},
        {"id": "main-column", "component": "Column", "children": \
      ["title", "time-row", "location-row", "description", "divider", "actions"]},
        {"id": "title", "component": "Text", "text": {"path": "/title"}, "variant": "h2"},
        {"id": "time-row", "component": "Row", "children": ["time-icon", "time-text"], \
      "align": "center"},
        {"id": "time-icon", "component": "Icon", "name": "calendarToday"},
        {"id": "time-text", "component": "Text", "text": {"call": "formatString", "args": \
      {"value": "\(tmpl)"}, "returnType": "string"}, "variant": "body"},
        {"id": "location-row", "component": "Row", "children": ["location-icon", "location-text"], \
      "align": "center"},
        {"id": "location-icon", "component": "Icon", "name": "locationOn"},
        {"id": "location-text", "component": "Text", "text": {"path": "/location"}, \
      "variant": "body"},
        {"id": "description", "component": "Text", "text": {"path": "/description"}, \
      "variant": "body"},
        {"id": "divider", "component": "Divider"},
        {"id": "actions", "component": "Row", "children": ["accept-btn", "decline-btn"]},
        {"id": "accept-btn-text", "component": "Text", "text": "Accept"},
        {"id": "accept-btn", "component": "Button", "child": "accept-btn-text", "action": \
      {"event": {"name": "accept", "context": {}}}},
        {"id": "decline-btn-text", "component": "Text", "text": "Decline"},
        {"id": "decline-btn", "component": "Button", "child": "decline-btn-text", "action": \
      {"event": {"name": "decline", "context": {}}}}
      ]}}
      """
    try processor.process(line: updateComponentsMsg)

    let updateDataMsg = """
      {"version": "v0.9", "updateDataModel": {"surfaceId": "gallery-event-detail", "value": {
        "title": "Product Launch Meeting",
        "start": "2025-12-19T14:00:00Z",
        "end": "2025-12-19T15:30:00Z",
        "location": "Conference Room A, Building 2",
        "description": "Review final product specs and marketing materials before the Q1 launch."
      }}}
      """
    try processor.process(line: updateDataMsg)

    guard let surface = processor.getSurface(id: "gallery-event-detail") else {
      Issue.record("Surface not found")
      return
    }

    let root = surface.rootNode
    guard let cardChild = root?.properties["child"] as? Node,
      let colChildren = cardChild.properties["children"] as? [Node],
      let timeRow = colChildren.first(where: { $0.id == "time-row" }),
      let timeChildren = timeRow.properties["children"] as? [Node],
      let timeTextNode = timeChildren.first(where: { $0.id == "time-text" }),
      let timeTextBinding = timeTextNode.properties["text"] as? DataBinding<String>
    else {
      Issue.record("Failed to resolve time-text node or binding")
      return
    }

    let formattedText = timeTextBinding.value ?? ""
    #expect(formattedText.contains("Fri, Dec 19"))
    #expect(formattedText.contains(" • "))
    #expect(formattedText.contains(" - "))
    #expect(!formattedText.contains("formatDate"))
    #expect(!formattedText.contains("${"))
  }

  @MainActor
  @Test func childListTemplateExpansionRendersItemsWithBoundValues() throws {
    let processor = MessageProcessor(catalogs: BasicCatalog.allCatalogs)
    try processor.process(
      line: """
        {"version": "v0.9", "createSurface": {"surfaceId": "gallery-child-list-template", "catalogId": "https://a2ui.org/specification/v0_9/catalogs/basic/catalog.json", "sendDataModel": true}}
        """)
    try processor.process(
      line: """
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
    try processor.process(
      line: """
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
      let listChildren = listNode.properties["children"] as? [Node]
    else {
      Issue.record("Failed to resolve list node tree")
      return
    }

    #expect(listChildren.count == 3)

    // Check item 0 (Apple - Qty: 10)
    let row0 = listChildren[0]
    #expect(row0.id == "item-row_0")
    guard let row0Children = row0.properties["children"] as? [Node],
      let name0 =
        (row0Children.first(where: { $0.id == "item-name" })?.properties["text"]
        as? DataBinding<String>)?.value,
      let qtyLabel0 =
        (row0Children.first(where: { $0.id == "qty-label" })?.properties["text"]
        as? DataBinding<String>)?.value,
      let qty0 =
        (row0Children.first(where: { $0.id == "item-qty" })?.properties["text"]
        as? DataBinding<String>)?.value
    else {
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
      let name1 =
        (row1Children.first(where: { $0.id == "item-name" })?.properties["text"]
        as? DataBinding<String>)?.value,
      let qty1 =
        (row1Children.first(where: { $0.id == "item-qty" })?.properties["text"]
        as? DataBinding<String>)?.value
    else {
      Issue.record("Row 1 children not found")
      return
    }
    #expect(name1 == "Banana")
    #expect(qty1 == "5")

    // Check item 2 (Cherry - Qty: 20)
    let row2 = listChildren[2]
    #expect(row2.id == "item-row_2")
    guard let row2Children = row2.properties["children"] as? [Node],
      let name2 =
        (row2Children.first(where: { $0.id == "item-name" })?.properties["text"]
        as? DataBinding<String>)?.value,
      let qty2 =
        (row2Children.first(where: { $0.id == "item-qty" })?.properties["text"]
        as? DataBinding<String>)?.value
    else {
      Issue.record("Row 2 children not found")
      return
    }
    #expect(name2 == "Cherry")
    #expect(qty2 == "20")
  }

  @MainActor
  @Test func musicPlayerExampleRendersIconsWithBoundAndLiteralNames() throws {
    let processor = MessageProcessor(catalogs: BasicCatalog.allCatalogs)
    try processor.process(
      line: """
        {"version": "v0.9", "createSurface": {"surfaceId": "gallery-music-player", "catalogId": "https://a2ui.org/specification/v0_9/catalogs/basic/catalog.json", "sendDataModel": true}}
        """)
    try processor.process(
      line: """
        {"version": "v0.9", "updateComponents": {"surfaceId": "gallery-music-player", "components": [
          {"id": "root", "component": "Card", "child": "main-column"},
          {"id": "main-column", "component": "Column", "children": ["controls"], "align": "center"},
          {"id": "controls", "component": "Row", "children": ["prev-btn", "play-btn", "next-btn"], "justify": "center"},
          {"id": "prev-btn-icon", "component": "Icon", "name": "skipPrevious"},
          {"id": "prev-btn", "component": "Button", "child": "prev-btn-icon", "action": {"event": {"name": "previous"}}},
          {"id": "play-btn-icon", "component": "Icon", "name": {"path": "/playIcon"}},
          {"id": "play-btn", "component": "Button", "child": "play-btn-icon", "action": {"event": {"name": "playPause"}}},
          {"id": "next-btn-icon", "component": "Icon", "name": "skipNext"},
          {"id": "next-btn", "component": "Button", "child": "next-btn-icon", "action": {"event": {"name": "next"}}}
        ]}}
        """)
    try processor.process(
      line: """
        {"version": "v0.9", "updateDataModel": {"surfaceId": "gallery-music-player", "value": {
          "playIcon": "pause"
        }}}
        """)

    guard let surface = processor.getSurface(id: "gallery-music-player") else {
      Issue.record("Surface not found")
      return
    }

    let root = surface.rootNode
    guard let cardChild = root?.properties["child"] as? Node,
      let colChildren = cardChild.properties["children"] as? [Node],
      let controlsRow = colChildren.first(where: { $0.id == "controls" }),
      let buttons = controlsRow.properties["children"] as? [Node]
    else {
      Issue.record("Failed to resolve music player controls")
      return
    }

    #expect(buttons.count == 3)

    // Check prev-btn-icon (literal "skipPrevious")
    guard let prevBtn = buttons.first(where: { $0.id == "prev-btn" }),
      let prevIconNode = prevBtn.properties["child"] as? Node
    else {
      Issue.record("prev-btn icon node not found")
      return
    }
    let prevName =
      (prevIconNode.properties["name"] as? DataBinding<String>)?.value
      ?? (prevIconNode.properties["name"] as? JSONValue)?.stringValue
    #expect(prevName == "skipPrevious")

    // Check play-btn-icon (data-bound "/playIcon" -> "pause")
    guard let playBtn = buttons.first(where: { $0.id == "play-btn" }),
      let playIconNode = playBtn.properties["child"] as? Node,
      let playBinding = playIconNode.properties["name"] as? DataBinding<String>
    else {
      Issue.record("play-btn icon node or binding not found")
      return
    }
    #expect(playBinding.value == "pause")

    // Live update playIcon in data model:
    surface.dataModel.set("/playIcon", value: .string("play"))
    let updatedRoot = surface.rootNode
    let updatedCardChild = updatedRoot?.properties["child"] as? Node
    let updatedColChildren = updatedCardChild?.properties["children"] as? [Node]
    let updatedControlsRow = updatedColChildren?.first(where: { $0.id == "controls" })
    let updatedPlayBtn = (updatedControlsRow?.properties["children"] as? [Node])?.first(where: { $0.id == "play-btn" })
    let updatedPlayIcon = updatedPlayBtn?.properties["child"] as? Node
    let updatedPlayBinding = updatedPlayIcon?.properties["name"] as? DataBinding<String>
    #expect(updatedPlayBinding?.value == "play")

    // Check next-btn-icon (literal "skipNext")
    guard let nextBtn = buttons.first(where: { $0.id == "next-btn" }),
      let nextIconNode = nextBtn.properties["child"] as? Node
    else {
      Issue.record("next-btn icon node not found")
      return
    }
    let nextName =
      (nextIconNode.properties["name"] as? DataBinding<String>)?.value
      ?? (nextIconNode.properties["name"] as? JSONValue)?.stringValue
    #expect(nextName == "skipNext")
  }

  @MainActor
  @Test func iconComponentResolvesSvgPath() throws {
    let processor = MessageProcessor(catalogs: BasicCatalog.allCatalogs)
    try processor.process(
      line: """
        {"version": "v0.9", "createSurface": {"surfaceId": "gallery-svg-icon", "catalogId": "https://a2ui.org/specification/v0_9/catalogs/basic/catalog.json"}}
        """)
    try processor.process(
      line: """
        {"version": "v0.9", "updateComponents": {"surfaceId": "gallery-svg-icon", "components": [
          {"id": "root", "component": "Icon", "name": {"svgPath": "M10 20 L30 40"}}
        ]}}
        """)

    guard let surface = processor.getSurface(id: "gallery-svg-icon"),
      let root = surface.rootNode
    else {
      Issue.record("Surface or root node not found")
      return
    }

    let iconName =
      (root.properties["name"] as? DataBinding<String>)?.value
      ?? (root.properties["name"] as? JSONValue)?.stringValue
    #expect(iconName == "svg:M10 20 L30 40")
  }
}
