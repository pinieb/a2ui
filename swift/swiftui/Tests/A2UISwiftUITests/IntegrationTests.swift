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

/// A simple action handler that records actions for integration tests.
final class IntegrationActionHandler: ActionHandling, @unchecked Sendable {
  var actions: [ResolvedAction] = []
  var errors: [ClientServerError] = []

  func handle(action: ResolvedAction, from surfaceID: String) {
    actions.append(action)
  }

  func handle(error: ClientServerError, from surfaceID: String) {
    errors.append(error)
  }
}

// MARK: - Integration Tests

@MainActor
struct IntegrationTests {

  // MARK: - Button + Text Binding

  @Test func textComponentResolvesLiteralString() throws {
    let catalog = BasicCatalog.v091Catalog
    let handler = IntegrationActionHandler()
    let processor = MessageProcessor(
      catalogs: [catalog.id: catalog],
      actionHandler: handler
    )

    try processor.process(line: """
      {"version": "v0.9.1", "createSurface": {"surfaceId": "s1", "catalogId": "\(catalog.id)"}}
      """)
    try processor.process(line: """
      {"version": "v0.9.1", "updateComponents": {"surfaceId": "s1", "components": [
        {"id": "root", "component": "Text", "text": "Hello, World!"}
      ]}}
      """)

    let vm = processor.getSurface(id: "s1")
    let root = vm?.rootNode
    #expect(root?.id == "root")
    #expect(root?.type == "Text")
    if let textProp = root?.properties["text"] as? DataBinding<String> {
      #expect(textProp.get() == "Hello, World!")
    } else {
      Issue.record("Expected DataBinding<String> for text property")
    }
  }

  @Test func buttonWithActionResolvesEvent() throws {
    let catalog = BasicCatalog.v091Catalog
    let handler = IntegrationActionHandler()
    let processor = MessageProcessor(
      catalogs: [catalog.id: catalog],
      actionHandler: handler
    )

    try processor.process(line: """
      {"version": "v0.9.1", "createSurface": {"surfaceId": "s1", "catalogId": "\(catalog.id)"}}
      """)
    try processor.process(line: """
      {"version": "v0.9.1", "updateComponents": {"surfaceId": "s1", "components": [
        {"id": "root", "component": "Button", "child": "btnText", "action": {"event": {"name": "submit", "context": {"formId": "contact"}}}},
        {"id": "btnText", "component": "Text", "text": "Click Me"}
      ]}}
      """)

    let vm = processor.getSurface(id: "s1")
    let root = vm?.rootNode
    #expect(root?.id == "root")
    #expect(root?.type == "Button")
    if let action = root?.properties["action"] as? ResolvedAction {
      if case .event(let name, let context) = action.identity {
        #expect(name == "submit")
        #expect(context?["formId"]?.stringValue == "contact")
      }
    } else {
      Issue.record("Expected ResolvedAction for action property")
    }
  }

  // MARK: - Multi-Step Form

  @Test func multiStepFormWithLiveValidation() throws {
    let catalog = BasicCatalog.v091Catalog
    let handler = IntegrationActionHandler()
    let processor = MessageProcessor(
      catalogs: [catalog.id: catalog],
      actionHandler: handler
    )

    try processor.process(line: """
      {"version": "v0.9.1", "createSurface": {"surfaceId": "form-surface", "catalogId": "\(catalog.id)"}}
      """)

    // Step 1: Create form with Column containing text fields and button
    try processor.process(line: """
      {"version": "v0.9.1", "updateComponents": {"surfaceId": "form-surface", "components": [
        {"id": "root", "component": "Column", "children": ["nameField", "emailField", "submitBtn"]},
        {"id": "nameField", "component": "TextField", "label": "Name", "value": {"path": "/form/name"}},
        {"id": "emailField", "component": "TextField", "label": "Email", "value": {"path": "/form/email"}},
        {"id": "submitBtn", "component": "Button", "child": "btnLabel", "action": {"event": {"name": "submitForm"}}},
        {"id": "btnLabel", "component": "Text", "text": {"path": "/form/submitLabel"}}
      ]}}
      """)

    // Step 2: Update data model with user input
    try processor.process(line: """
      {"version": "v0.9.1", "updateDataModel": {"surfaceId": "form-surface", "path": "/form/name", "value": "Alice"}}
      """)
    try processor.process(line: """
      {"version": "v0.9.1", "updateDataModel": {"surfaceId": "form-surface", "path": "/form/email", "value": "alice@example.com"}}
      """)
    try processor.process(line: """
      {"version": "v0.9.1", "updateDataModel": {"surfaceId": "form-surface", "path": "/form/submitLabel", "value": "Submit Form"}}
      """)

    let vm = processor.getSurface(id: "form-surface")
    #expect(vm?.dataModel.get("/form/name")?.stringValue == "Alice")
    #expect(vm?.dataModel.get("/form/email")?.stringValue == "alice@example.com")
    #expect(vm?.dataModel.get("/form/submitLabel")?.stringValue == "Submit Form")

    let root = vm?.rootNode
    #expect(root?.id == "root")
    guard let children = root?.properties["children"] as? [Node] else {
      Issue.record("Expected [Node] children")
      return
    }
    #expect(children.count == 3)

    // Verify two-way binding on nameField
    let nameField = children.first { $0.id == "nameField" }
    guard let nameBinding = nameField?.properties["value"] as? DataBinding<String> else {
      Issue.record("Expected DataBinding<String> for nameField value")
      return
    }
    #expect(nameBinding.get() == "Alice")
    nameBinding.set("Bob")
    #expect(vm?.dataModel.get("/form/name")?.stringValue == "Bob")
  }

  @MainActor
  @Test func testFormattedTextDynamicEvaluation() throws {
    let processor = MessageProcessor(catalogs: BasicCatalog.allCatalogs)
    let catalogImpl = CatalogImplementation.basic()

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

    guard let surfaceVM = processor.getSurface(id: "gallery-formatted-text") else {
      Issue.record("Surface not found")
      return
    }

    let surfaceView = Surface(viewModel: surfaceVM, catalogImplementation: catalogImpl)
    #expect(surfaceView != nil)

    guard let root = surfaceVM.rootNode,
          let children = root.properties["children"] as? [Node],
          let inputFieldNode = children.first(where: { $0.id == "input_field" }),
          let resultTextNode = children.first(where: { $0.id == "result_text" }),
          let inputBinding = inputFieldNode.properties["value"] as? DataBinding<String>,
          let resultBinding = resultTextNode.properties["text"] as? DataBinding<String>
    else {
      Issue.record("Failed to resolve child nodes or bindings")
      return
    }

    // Step 1: Initial state before any typing
    #expect(inputBinding.get() == "")
    #expect(resultBinding.get() == "You typed: ")

    // Step 2: User types "Beep this is the update." in input_field
    inputBinding.set("Beep this is the update.")

    // Step 3: Verify DataModel received the input
    #expect(surfaceVM.dataModel.get("/inputValue")?.stringValue == "Beep this is the update.")

    // Step 4: Verify formatted text binding immediately yields the updated string
    #expect(resultBinding.get() == "You typed: Beep this is the update.")

    // Step 5: User types more
    inputBinding.set("Final Check 123")
    #expect(resultBinding.get() == "You typed: Final Check 123")
  }

  @MainActor
  @Test func testChildListTemplateExpansionSurfaceRendering() throws {
    let processor = MessageProcessor(catalogs: BasicCatalog.allCatalogs)
    let catalogImpl = CatalogImplementation.basic()

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

    guard let surfaceVM = processor.getSurface(id: "gallery-child-list-template") else {
      Issue.record("Surface not found")
      return
    }

    let surfaceView = Surface(viewModel: surfaceVM, catalogImplementation: catalogImpl)
    #expect(surfaceView != nil)

    guard let root = surfaceVM.rootNode,
          let cardChild = root.properties["child"] as? Node,
          let colChildren = cardChild.properties["children"] as? [Node],
          let listNode = colChildren.first(where: { $0.id == "item-list" }),
          let listChildren = listNode.properties["children"] as? [Node] else {
      Issue.record("Failed to resolve list node tree")
      return
    }

    #expect(listChildren.count == 3)

    let itemsExpected: [(String, String)] = [
      ("Apple", "10"),
      ("Banana", "5"),
      ("Cherry", "20"),
    ]

    for (index, expected) in itemsExpected.enumerated() {
      let row = listChildren[index]
      guard let rowChildren = row.properties["children"] as? [Node],
            let name = (rowChildren.first(where: { $0.id == "item-name" })?.properties["text"] as? DataBinding<String>)?.get(),
            let qty = (rowChildren.first(where: { $0.id == "item-qty" })?.properties["text"] as? DataBinding<String>)?.get() else {
        Issue.record("Failed to read row \(index) children")
        continue
      }
      #expect(name == expected.0)
      #expect(qty == expected.1)
    }
  }
}
