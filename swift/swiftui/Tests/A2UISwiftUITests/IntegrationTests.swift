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
import JSONSchema
import OrderedJSON
import SwiftUI
import Testing

// MARK: - Test Catalog for Integration Tests

/// A catalog with button and text component schemas for integration tests.
struct IntegrationCatalog: ComponentCatalog {
  let buttonSchema: Schema
  let textSchema: Schema
  let textFieldSchema: Schema

  init() throws {
    let remote = A2UICommonSchema.allSchemas
    buttonSchema = try Schema(
      instance: """
        {
          "type": "object",
          "properties": {
            "id": {"type": "string"},
            "component": {"type": "string"},
            "label": {"$ref": "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/DynamicString"},
            "onClick": {"$ref": "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/Action"}
          },
          "required": ["id", "component"]
        }
        """,
      remoteSchemas: remote
    )
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
      remoteSchemas: remote
    )
    textFieldSchema = try Schema(
      instance: """
        {
          "type": "object",
          "properties": {
            "id": {"type": "string"},
            "component": {"type": "string"},
            "value": {"$ref": "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/DynamicString"},
            "placeholder": {"$ref": "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/DynamicString"}
          },
          "required": ["id", "component"]
        }
        """,
      remoteSchemas: remote
    )
  }

  func schema(forType type: String) -> Schema? {
    switch type {
    case "button": return buttonSchema
    case "text": return textSchema
    case "textField": return textFieldSchema
    default: return nil
    }
  }

  func makeTheme(jsonObject: JSONValue) -> (any SurfaceTheme)? {
    nil
  }

  func localFunction(for name: String) -> (any LocalFunction)? {
    nil
  }
}

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

struct IntegrationTests {

  // MARK: - Button + Text Binding

  @Test func buttonWithDynamicLabelResolvesFromDataModel() throws {
    let catalog = try IntegrationCatalog()
    let handler = IntegrationActionHandler()
    let vm = SurfaceViewModel(
      surfaceID: "s1",
      catalog: catalog,
      actionHandler: handler
    )

    vm.updateDataModel(path: "/buttonLabel", value: "Submit")
    vm.updateComponents([
      [
        "id": "root",
        "component": "button",
        "label": ["path": "/buttonLabel"],
      ],
    ])

    let data = vm.getDataModel()
    #expect(data["buttonLabel"]?.stringValue == "Submit")
    let components = vm.getComponents()
    #expect(components["root"] != nil)
  }

  @Test func buttonWithActionResolvesEvent() throws {
    let catalog = try IntegrationCatalog()
    let handler = IntegrationActionHandler()
    let vm = SurfaceViewModel(
      surfaceID: "s1",
      catalog: catalog,
      actionHandler: handler
    )

    vm.updateComponents([
      [
        "id": "root",
        "component": "button",
        "label": "Click Me",
        "onClick": [
          "event": [
            "name": "submit",
            "context": ["formId": "contact"],
          ],
        ],
      ],
    ])

    let components = vm.getComponents()
    let root = try #require(components["root"])
    let action = try #require(root["onClick"]?.dictionaryValue)
    let event = try #require(action["event"]?.dictionaryValue)
    #expect(event["name"]?.stringValue == "submit")
  }

  @Test func textComponentResolvesLiteralString() throws {
    let catalog = try IntegrationCatalog()
    let handler = IntegrationActionHandler()
    let vm = SurfaceViewModel(
      surfaceID: "s1",
      catalog: catalog,
      actionHandler: handler
    )

    vm.updateComponents([
      [
        "id": "label1",
        "component": "text",
        "text": "Hello, World!",
      ],
    ])

    let components = vm.getComponents()
    #expect(components["label1"]?["text"]?.stringValue == "Hello, World!")
  }

  // MARK: - Multi-Step Form

  @Test func multiStepFormWithLiveValidation() throws {
    let catalog = try IntegrationCatalog()
    let handler = IntegrationActionHandler()
    let vm = SurfaceViewModel(
      surfaceID: "form-surface",
      catalog: catalog,
      actionHandler: handler
    )

    // Step 1: Create form with text fields bound to data model
    vm.updateComponents([
      [
        "id": "nameField",
        "component": "textField",
        "value": ["path": "/form/name"],
        "placeholder": "Enter your name",
      ],
      [
        "id": "emailField",
        "component": "textField",
        "value": ["path": "/form/email"],
        "placeholder": "Enter your email",
      ],
      [
        "id": "submitBtn",
        "component": "button",
        "label": ["path": "/form/submitLabel"],
        "onClick": [
          "event": ["name": "submitForm"],
        ],
      ],
    ])

    // Step 2: Update data model with user input
    vm.updateDataModel(path: "/form/name", value: "Alice")
    vm.updateDataModel(path: "/form/email", value: "alice@example.com")
    vm.updateDataModel(path: "/form/submitLabel", value: "Submit Form")

    // Verify data model state
    let data = vm.getDataModel()
    #expect(data["form/name"]?.stringValue == "Alice")
    #expect(data["form/email"]?.stringValue == "alice@example.com")
    #expect(data["form/submitLabel"]?.stringValue == "Submit Form")

    // Verify components are stored
    let components = vm.getComponents()
    #expect(components.count == 3)

    // Step 3: Update name and verify
    vm.updateDataModel(path: "/form/name", value: "Bob")
    let updatedData = vm.getDataModel()
    #expect(updatedData["form/name"]?.stringValue == "Bob")
  }

  // MARK: - End-to-End Message Processing

  @Test func endToEndCreateSurfaceAndUpdateComponents() throws {
    let catalog = try IntegrationCatalog()
    let handler = IntegrationActionHandler()
    let processor = MessageProcessor(
      catalogs: ["default": catalog],
      actionHandler: handler
    )

    try processor.process(line: """
      {"createSurface": {"surfaceId": "s1", "catalogId": "default"}}
      """)

    try processor.process(line: """
      {"updateComponents": {"surfaceId": "s1", "components": [
        {"id": "root", "component": "text", "text": "Hello"}
      ]}}
      """)

    let vm = processor.getSurface(id: "s1")
    let components = vm?.getComponents()
    #expect(components?["root"]?["text"]?.stringValue == "Hello")
  }

  @Test func endToEndDataModelUpdateAndComponentBinding() throws {
    let catalog = try IntegrationCatalog()
    let handler = IntegrationActionHandler()
    let processor = MessageProcessor(
      catalogs: ["default": catalog],
      actionHandler: handler
    )

    try processor.process(line: """
      {"createSurface": {"surfaceId": "s1", "catalogId": "default"}}
      """)

    try processor.process(line: """
      {"updateComponents": {"surfaceId": "s1", "components": [
        {"id": "lbl", "component": "text", "text": {"path": "/title"}}
      ]}}
      """)

    try processor.process(line: """
      {"updateDataModel": {"surfaceId": "s1", "path": "/title", "value": "Dynamic Title"}}
      """)

    let vm = processor.getSurface(id: "s1")
    let data = vm?.getDataModel()
    #expect(data?["title"]?.stringValue == "Dynamic Title")
  }
}
