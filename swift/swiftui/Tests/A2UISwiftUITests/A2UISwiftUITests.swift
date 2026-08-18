// Copyright 2024 Google LLC
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
import BasicCatalog
@testable import BasicCatalogSwiftUI
import JSONSchema
import OrderedJSON
import SwiftUI
import Testing

// MARK: - Test Helpers

/// A simple view for testing that renders a component node's type and ID.
struct TestComponentView: View {
  let node: Node

  init(node: Node) {
    self.node = node
  }

  var body: some View {
    VStack {
      Text("Type: \(node.type)")
      Text("ID: \(node.id)")
    }
  }
}

// MARK: - Surface Tests

@MainActor
struct SurfaceTests {

  @Test func surfaceInitializesWithViewModel() throws {
    let catalog = try makeTestSurfaceCatalogForRendering()
    let viewModel = SurfaceViewModel(
      surfaceID: "s1",
      catalog: catalog
    )
    let catalogImplementation = CatalogImplementation()
    let surface = Surface(
      viewModel: viewModel,
      catalogImplementation: catalogImplementation
    )
    #expect(surface.surfaceID == "s1")
  }

  @Test func surfaceIDMatchesViewModel() throws {
    let catalog = try makeTestSurfaceCatalogForRendering()
    let viewModel = SurfaceViewModel(
      surfaceID: "s1",
      catalog: catalog
    )
    let firstSurface = Surface(
      viewModel: viewModel
    )
    let secondSurface = Surface(
      viewModel: viewModel
    )
    #expect(firstSurface.surfaceID == secondSurface.surfaceID)
  }

  @Test func surfaceDifferentSurfaceIDs() throws {
    let catalog = try makeTestSurfaceCatalogForRendering()
    let firstViewModel = SurfaceViewModel(
      surfaceID: "s1",
      catalog: catalog
    )
    let secondViewModel = SurfaceViewModel(
      surfaceID: "s2",
      catalog: catalog
    )
    let firstSurface = Surface(
      viewModel: firstViewModel
    )
    let secondSurface = Surface(
      viewModel: secondViewModel
    )
    #expect(firstSurface.surfaceID != secondSurface.surfaceID)
  }
}

// MARK: - DataBinding+SwiftUI Tests

struct DataBindingSwiftUITests {

  @Test func swiftUIBindingGetsValue() {
    let box = TestBox("hello")
    let binding = DataBinding<String>(
      identity: .path("/text"),
      value: "hello",
      set: { box.value = $0 }
    )
    let swiftBinding = binding.swiftUIBinding
    #expect(swiftBinding.wrappedValue == "hello")
  }

  @Test func swiftUIBindingSetsValue() {
    let box = TestBox("hello")
    let binding = DataBinding<String>(
      identity: .path("/text"),
      value: "hello",
      set: { box.value = $0 }
    )
    let swiftBinding = binding.swiftUIBinding
    swiftBinding.wrappedValue = "world"
    #expect(box.value == "world")
  }

  @Test func swiftUIBindingGetsAndSetsValue() {
    let box = TestBox(42.0)
    let binding = DataBinding<Double>(
      identity: .path("/value"),
      value: 42.0,
      set: { box.value = $0 }
    )
    let swiftBinding = binding.swiftUIBinding
    #expect(swiftBinding.wrappedValue == 42.0)
    swiftBinding.wrappedValue = 99.0
    #expect(box.value == 99.0)
  }

  @Test func swiftUIBindingWithDefaultFallback() {
    let box = TestBox("default")
    let binding = DataBinding<String>(
      identity: .path("/text"),
      value: nil,
      set: { box.value = $0 }
    )
    let swiftBinding = binding.swiftUIBinding(default: "fallback")
    #expect(swiftBinding.wrappedValue == "fallback")
    swiftBinding.wrappedValue = "updated"
    #expect(box.value == "updated")
  }

  @Test func stringBindingDefaultsToEmptyString() {
    let box = TestBox("")
    let binding = DataBinding<String>(
      identity: .path("/text"),
      value: nil,
      set: { box.value = $0 }
    )
    let swiftBinding = binding.stringBinding
    #expect(swiftBinding.wrappedValue == "")
    swiftBinding.wrappedValue = "typed"
    #expect(box.value == "typed")
  }

  @Test func nodeBindingAccessors() {
    let boxString = TestBox("initial")
    let boxDouble = TestBox(0.45)
    let boxBool = TestBox(true)
    let boxList = TestBox(["a", "b"])

    let node = Node(
      id: "testNode",
      type: "form",
      properties: [
        "title": DataBinding<String>(
          identity: .path("/title"), value: "initial", set: { boxString.value = $0 }),
        "progress": DataBinding<Double>(
          identity: .path("/progress"), value: 0.45, set: { boxDouble.value = $0 }),
        "active": DataBinding<Bool>(
          identity: .path("/active"), value: true, set: { boxBool.value = $0 }),
        "tags": DataBinding<[String]>(
          identity: .path("/tags"), value: ["a", "b"], set: { boxList.value = $0 }),
      ]
    )

    let strBinding = node.binding(for: "title", default: "")
    #expect(strBinding.wrappedValue == "initial")
    strBinding.wrappedValue = "new title"
    #expect(boxString.value == "new title")

    let dblBinding = node.binding(for: "progress", default: 0.0)
    #expect(dblBinding.wrappedValue == 0.45)
    dblBinding.wrappedValue = 0.9
    #expect(boxDouble.value == 0.9)

    let bBinding = node.binding(for: "active", default: false)
    #expect(bBinding.wrappedValue == true)
    bBinding.wrappedValue = false
    #expect(boxBool.value == false)

    let listBinding = node.binding(for: "tags", default: [String]())
    #expect(listBinding.wrappedValue == ["a", "b"])
    listBinding.wrappedValue = ["c"]
    #expect(boxList.value == ["c"])

    // Optional binding
    let optBinding: Binding<String?> = node.optionalBinding(for: "title")
    #expect(optBinding.wrappedValue == "initial")
    optBinding.wrappedValue = "opt title"
    #expect(boxString.value == "opt title")

    // Fallbacks for missing properties
    let missingNode = Node(id: "empty", type: "form", properties: [:])
    #expect(missingNode.binding(for: "missing", default: "fallback").wrappedValue == "fallback")
    #expect(missingNode.binding(for: "missing", default: Double(1.0)).wrappedValue == 1.0)
    #expect(missingNode.binding(for: "missing", default: true).wrappedValue == true)
    let missingOpt: Binding<Double?> = missingNode.optionalBinding(for: "missing")
    #expect(missingOpt.wrappedValue == nil)
  }
}

// MARK: - Theme Environment Tests

struct ThemeEnvironmentTests {

  @Test func themeKeyDefaultValueIsNil() {
    #expect(A2UIThemeKey.defaultValue == nil)
  }

  @Test func themeEnvironmentCanBeSet() throws {
    let theme: [String: JSONValue] = ["color": .string("blue")]
    var environment = EnvironmentValues()
    environment.a2uiTheme = theme
    #expect(environment.a2uiTheme != nil)
    #expect(environment.a2uiTheme?["color"]?.stringValue == "blue")
  }

  @Test func themeEnvironmentDefaultsToNil() {
    let environment = EnvironmentValues()
    #expect(environment.a2uiTheme == nil)
  }
}

// MARK: - CatalogImplementation Tests

@MainActor
struct CatalogImplementationTests {

  @Test func componentKeyEquality() {
    let firstKey = ComponentKey(
      catalogID: "catalogA",
      type: "button"
    )
    let secondKey = ComponentKey(
      catalogID: "catalogA",
      type: "button"
    )
    let thirdKey = ComponentKey(
      catalogID: "catalogB",
      type: "button"
    )
    #expect(firstKey == secondKey)
    #expect(firstKey != thirdKey)
  }

  @Test func catalogImplementationResolvesUnqualifiedFallback() {
    let catalogImplementation = CatalogImplementation()
    catalogImplementation.register(
      type: "button",
      builder: { node in AnyView(Text(node.type)) }
    )
    let builder = catalogImplementation.builder(
      catalogID: "catalogA",
      type: "button"
    )
    #expect(builder != nil)

    let node = Node(
      id: "btn1",
      type: "button",
      catalogID: "catalogA",
      properties: [:]
    )
    let renderedView = Surface.render(node: node, using: catalogImplementation)
    #expect(renderedView != nil)
  }

  @Test func catalogImplementationResolvesQualifiedKeyOverFallback() {
    let catalogImplementation = CatalogImplementation()
    var qualifiedCalled = false
    var fallbackCalled = false

    catalogImplementation.register(
      catalogID: "catalogA",
      type: "button",
      builder: { _ in
        qualifiedCalled = true
        return AnyView(Text("Qualified"))
      }
    )
    catalogImplementation.register(
      type: "button",
      builder: { _ in
        fallbackCalled = true
        return AnyView(Text("Fallback"))
      }
    )

    let node = Node(
      id: "btn1",
      type: "button",
      catalogID: "catalogA",
      properties: [:]
    )
    _ = Surface.render(node: node, using: catalogImplementation)
    #expect(qualifiedCalled)
    #expect(!fallbackCalled)
  }

  @Test func catalogImplementationRegistersComponentImplementation() throws {
    let schema = try Schema(instance: "{\"type\": \"object\"}")
    var builderCalled = false
    let component = ComponentImplementation(
      name: "map",
      schema: schema
    ) { _ in
      builderCalled = true
      return AnyView(Text("Map"))
    }

    #expect(component.name == "map")
    #expect(component.api.name == "map")
    #expect(component.schema == schema)

    let catalogImplementation = CatalogImplementation(
      catalogID: "mapsCatalog",
      components: [component]
    )

    let node = Node(
      id: "map1",
      type: "map",
      catalogID: "mapsCatalog",
      properties: [:]
    )
    _ = Surface.render(node: node, using: catalogImplementation)
    #expect(builderCalled)
  }

  @Test func catalogImplementationEnvironmentDefaultsToNil() {
    let environment = EnvironmentValues()
    #expect(environment.a2uiCatalogImplementation == nil)
  }

  @Test func catalogImplementationEnvironmentCanBeSet() {
    var environment = EnvironmentValues()
    let catalogImplementation = CatalogImplementation()
    environment.a2uiCatalogImplementation = catalogImplementation
    #expect(environment.a2uiCatalogImplementation != nil)
  }
}

// MARK: - Helpers

/// A mutable box for testing Sendable closures.
final class TestBox<T>: @unchecked Sendable {
  var value: T
  init(_ value: T) { self.value = value }
}

/// Helper function returning a catalog with a simple text schema for rendering tests.
func makeTestSurfaceCatalogForRendering() throws -> Catalog {
  let textSchema = try Schema(
    instance: """
      {
        "type": "object",
        "properties": {
          "id": { "type": "string" },
          "component": { "type": "string" },
          "text": { "$ref": "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/DynamicString" }
        },
        "required": ["id", "component"]
      }
      """,
    remoteSchemas: A2UICommonSchema.allSchemas
  )
  return Catalog(
    id: "default",
    components: [
      ComponentAPI(
        name: "text",
        schema: textSchema
      )
    ]
  )
}

// MARK: - AudioPlayer Tests

@MainActor
struct A2UIAudioPlayerTests {

  @Test func audioPlayerInitializesWithNode() {
    let node = Node(
      id: "audio1",
      type: "AudioPlayer",
      properties: [
        "url": "https://example.com/podcast.mp3",
        "description": "Episode 1: Introduction",
      ]
    )

    let view = A2UIAudioPlayer(node: node)
    #expect(node.string(for: "url") == "https://example.com/podcast.mp3")
    #expect(node.string(for: "description") == "Episode 1: Introduction")
    _ = view.body
  }

  @Test func audioPlayerModelScrubbingLifecycle() {
    let model = AudioPlayerModel()
    #expect(!model.isPlaying)
    #expect(model.currentTime == 0)
    #expect(model.duration == 0)
    #expect(!model.isScrubbing)

    model.onScrubStart()
    #expect(model.isScrubbing)

    model.onScrubChange(45.5)
    #expect(model.scrubValue == 45.5)

    model.onScrubEnd(45.5)
    #expect(!model.isScrubbing)
    #expect(model.currentTime == 45.5)

    model.cleanup()
    #expect(!model.isPlaying)
    #expect(model.currentTime == 0)
  }

  @Test func audioPlayerRendersFromBasicCatalogImplementation() throws {
    let impl = CatalogImplementation()
    impl.register(components: BasicCatalogImplementation.allComponents)

    let node = Node(
      id: "audioNode",
      type: "AudioPlayer",
      properties: [
        "url": "https://example.com/audio.mp3",
        "description": "Sample Track",
      ]
    )

    let rendered = Surface.render(node: node, using: impl)
    #expect(rendered != nil)
  }
}

// MARK: - DateTimeInput Tests

@MainActor
struct A2UIDateTimeInputTests {

  @Test func dateTimeInputInitializesWithProperties() {
    let node = Node(
      id: "dt1",
      type: "DateTimeInput",
      properties: [
        "label": "Event Date",
        "value": "2024-12-15T14:30:00Z",
        "enableDate": true,
        "enableTime": true,
        "min": "2024-01-01T00:00:00Z",
        "max": "2025-12-31T23:59:59Z",
      ]
    )

    let view = A2UIDateTimeInput(node: node)
    #expect(node.string(for: "label") == "Event Date")
    #expect(node.string(for: "value") == "2024-12-15T14:30:00Z")
    #expect(node.bool(for: "enableDate") == true)
    #expect(node.bool(for: "enableTime") == true)
    #expect(node.string(for: "min") == "2024-01-01T00:00:00Z")
    #expect(node.string(for: "max") == "2025-12-31T23:59:59Z")
    _ = view.body
  }

  @Test func dateTimeInputRendersDateOnly() {
    let node = Node(
      id: "dtDateOnly",
      type: "DateTimeInput",
      properties: [
        "label": "Birthday",
        "value": "1990-05-20",
        "enableDate": true,
        "enableTime": false,
      ]
    )

    let view = A2UIDateTimeInput(node: node)
    _ = view.body
  }

  @Test func dateTimeInputRendersTimeOnly() {
    let node = Node(
      id: "dtTimeOnly",
      type: "DateTimeInput",
      properties: [
        "label": "Alarm",
        "value": "08:30:00",
        "enableDate": false,
        "enableTime": true,
      ]
    )

    let view = A2UIDateTimeInput(node: node)
    _ = view.body
  }

  @Test func dateTimeInputRendersFromCatalog() throws {
    let impl = CatalogImplementation()
    impl.register(components: BasicCatalogImplementation.allComponents)

    let node = Node(
      id: "dtCatalog",
      type: "DateTimeInput",
      properties: [
        "label": "Booking Date",
        "value": "2024-12-25",
        "enableDate": true,
      ]
    )

    let rendered = Surface.render(node: node, using: impl)
    #expect(rendered != nil)
  }
}

// MARK: - List Tests

@MainActor
struct A2UIListTests {

  @Test func verticalListInitializesWithAlignAndChildren() {
    let child1 = Node(id: "c1", type: "Text", properties: ["text": "First"])
    let child2 = Node(id: "c2", type: "Text", properties: ["text": "Second"])
    let node = Node(
      id: "list1",
      type: "List",
      properties: [
        "direction": "vertical",
        "align": "center",
        "children": [child1, child2],
      ]
    )

    let view = A2UIList(node: node)
    #expect(node.string(for: "direction") == "vertical")
    #expect(node.string(for: "align") == "center")
    #expect(node.children(for: "children").count == 2)
    _ = view.body
  }

  @Test func horizontalListInitializesWithAlign() {
    let child1 = Node(id: "c1", type: "Text", properties: ["text": "Card A"])
    let node = Node(
      id: "list2",
      type: "List",
      properties: [
        "direction": "horizontal",
        "align": "start",
        "children": [child1],
      ]
    )

    let view = A2UIList(node: node)
    #expect(node.string(for: "direction") == "horizontal")
    #expect(node.string(for: "align") == "start")
    _ = view.body
  }

  @Test func listRendersFromCatalog() throws {
    let impl = CatalogImplementation()
    impl.register(components: BasicCatalogImplementation.allComponents)

    let child = Node(id: "c1", type: "Text", properties: ["text": "Item"])
    let node = Node(
      id: "listCatalog",
      type: "List",
      properties: [
        "direction": "vertical",
        "align": "stretch",
        "children": [child],
      ]
    )

    let rendered = Surface.render(node: node, using: impl)
    #expect(rendered != nil)
  }
}

// MARK: - ChoicePicker Tests

@MainActor
struct A2UIChoicePickerTests {

  @Test func choicePickerInitializesWithChips() {
    let node = Node(
      id: "picker1",
      type: "ChoicePicker",
      properties: [
        "label": "Billing Period",
        "displayStyle": "chips",
        "variant": "mutuallyExclusive",
        "value": ["annual"],
        "options": JSONValue.array([
          JSONValue.object(["label": .string("Annual"), "value": .string("annual")]),
          JSONValue.object(["label": .string("Monthly"), "value": .string("monthly")]),
        ]),
      ]
    )

    let view = A2UIChoicePicker(node: node)
    #expect(node.string(for: "label") == "Billing Period")
    #expect(node.string(for: "displayStyle") == "chips")
    #expect(node.string(for: "variant") == "mutuallyExclusive")
    _ = view.body
  }

  @Test func choicePickerInitializesWithCheckboxAndFilter() {
    let node = Node(
      id: "picker2",
      type: "ChoicePicker",
      properties: [
        "label": "Interests",
        "displayStyle": "checkbox",
        "variant": "multipleSelection",
        "filterable": true,
        "value": ["sports", "music"],
        "options": JSONValue.array([
          JSONValue.object(["label": .string("Sports"), "value": .string("sports")]),
          JSONValue.object(["label": .string("Music"), "value": .string("music")]),
          JSONValue.object(["label": .string("Tech"), "value": .string("tech")]),
        ]),
      ]
    )

    let view = A2UIChoicePicker(node: node)
    #expect(node.bool(for: "filterable") == true)
    _ = view.body
  }

  @Test func choicePickerInitializesWithResolvedArray() {
    let opt1 = ResolvedDictionary(["label": "Annual", "value": "annual"])
    let opt2 = ResolvedDictionary(["label": "Monthly", "value": "monthly"])
    let node = Node(
      id: "pickerResolved",
      type: "ChoicePicker",
      properties: [
        "label": "Billing Period",
        "displayStyle": "chips",
        "variant": "mutuallyExclusive",
        "value": ["annual"],
        "options": ResolvedArray([opt1, opt2]),
      ]
    )

    let view = A2UIChoicePicker(node: node)
    _ = view.body
  }

  @Test func choicePickerRendersFromCatalog() throws {
    let impl = CatalogImplementation()
    impl.register(components: BasicCatalogImplementation.allComponents)

    let node = Node(
      id: "pickerCatalog",
      type: "ChoicePicker",
      properties: [
        "label": "Subscription",
        "displayStyle": "chips",
        "options": JSONValue.array([
          JSONValue.object(["label": .string("Plan A"), "value": .string("planA")]),
        ]),
      ]
    )

    let rendered = Surface.render(node: node, using: impl)
    #expect(rendered != nil)
  }
}

// MARK: - Icon Tests

@MainActor
struct A2UIIconTests {

  @Test func iconInitializesWithSymbolName() {
    let node = Node(
      id: "icon1",
      type: "Icon",
      properties: ["name": "star"]
    )

    let view = A2UIIcon(node: node)
    _ = view.body
  }

  @Test func iconInitializesWithSVGPath() {
    let node = Node(
      id: "iconSVG",
      type: "Icon",
      properties: [
        "name": ResolvedDictionary([
          "svgPath": "M10 10 H 90 V 90 H 10 Z"
        ])
      ]
    )

    let view = A2UIIcon(node: node)
    _ = view.body
  }

  @Test func svgPathParserParsesCommands() {
    let path = SVGPathParser.parse("M0 0 L10 10 H20 V30 C1 2 3 4 5 6 S7 8 9 10 Q11 12 13 14 T15 16 Z")
    #expect(!path.isEmpty)
  }

  @Test func iconDataBoundSVGPathRendersEndToEnd() async throws {
    let catalog = Catalog(
      id: "https://a2ui.org/specification/v0_9/catalogs/basic/catalog.json",
      components: BasicCatalogComponents.allComponents
    )
    let processor = MessageProcessor(catalogs: [catalog])
    let group = processor.surfaceGroupModel
    let impl = CatalogImplementation()
    impl.register(components: BasicCatalogImplementation.allComponents)

    // Step 1: Create surface
    let createMsg: [String: Any] = [
      "version": "v0.9",
      "createSurface": [
        "surfaceId": "test-svg",
        "catalogId": "https://a2ui.org/specification/v0_9/catalogs/basic/catalog.json",
        "sendDataModel": true
      ]
    ]
    let cData = try JSONSerialization.data(withJSONObject: createMsg)
    try processor.process(line: String(data: cData, encoding: .utf8)!)

    // Step 2: updateComponents with data-bound name
    let updateCompMsg: [String: Any] = [
      "version": "v0.9",
      "updateComponents": [
        "surfaceId": "test-svg",
        "components": [
          [
            "id": "root",
            "component": "Icon",
            "name": [
              "path": "/shieldIcon"
            ]
          ]
        ]
      ]
    ]
    let uData = try JSONSerialization.data(withJSONObject: updateCompMsg)
    try processor.process(line: String(data: uData, encoding: .utf8)!)

    await Task.yield()
    guard let surface = group.surfacesMap["test-svg"] else {
      Issue.record("Missing surface")
      return
    }

    let nodeBefore = surface.rootNode
    #expect(nodeBefore != nil)

    // Step 3: updateDataModel
    let updateDataMsg: [String: Any] = [
      "version": "v0.9",
      "updateDataModel": [
        "surfaceId": "test-svg",
        "value": [
          "shieldIcon": [
            "svgPath": "M12 1L3 5v6c0 5.55 3.84 10.74 9 12 5.16-1.26 9-6.45 9-12V5l-9-4zm-2 16l-4-4 1.41-1.41L10 14.17l6.59-6.59L18 9l-8 8z"
          ]
        ]
      ]
    ]
    let dData = try JSONSerialization.data(withJSONObject: updateDataMsg)
    try processor.process(line: String(data: dData, encoding: .utf8)!)

    await Task.yield()
    let nodeAfter = surface.rootNode
    #expect(nodeAfter != nil)
    let iconView = A2UIIcon(node: try #require(nodeAfter))
    #expect(iconView.iconSource == A2UIIcon.IconSource.svg("M12 1L3 5v6c0 5.55 3.84 10.74 9 12 5.16-1.26 9-6.45 9-12V5l-9-4zm-2 16l-4-4 1.41-1.41L10 14.17l6.59-6.59L18 9l-8 8z"))
  }
}






