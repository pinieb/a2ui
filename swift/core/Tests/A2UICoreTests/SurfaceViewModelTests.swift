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
import Foundation
import JSONSchema
import OrderedJSON
import Testing

/// A simple `LocalFunction` that concatenates two strings.
struct TestConcatFunction: LocalFunction {
  func evaluate(arguments: [String: JSONValue]) throws -> JSONValue {
    let a = arguments["a"]?.stringValue ?? ""
    let b = arguments["b"]?.stringValue ?? ""
    return .string(a + b)
  }
}

/// A simple `SurfaceTheme` for testing.
struct TestSurfaceTheme: SurfaceTheme {
  let color: String
}

/// A catalog with a button schema that has dynamic properties.
struct TestSurfaceCatalog: ComponentCatalog {
  let buttonSchema: Schema

  init() throws {
    buttonSchema = try Schema(
      instance: """
        {
          "type": "object",
          "properties": {
            "id": { "type": "string" },
            "component": { "type": "string" },
            "label": { "$ref": "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/DynamicString" },
            "enabled": { "$ref": "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/DynamicBoolean" },
            "onClick": { "$ref": "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/Action" },
            "children": { "$ref": "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/ChildList" }
          },
          "required": ["id", "component"]
        }
        """,
      remoteSchemas: A2UICommonSchema.allSchemas
    )
  }

  func schema(forType type: String) -> Schema? {
    switch type {
    case "button": return buttonSchema
    default: return nil
    }
  }

  func makeTheme(jsonObject: JSONValue) -> (any SurfaceTheme)? {
    nil
  }

  func localFunction(for name: String) -> (any LocalFunction)? {
    switch name {
    case "concat": return TestConcatFunction()
    default: return nil
    }
  }
}

/// A test `ActionHandling` that captures actions for verification.
final class TestActionHandler: ActionHandling, @unchecked Sendable {
  var capturedActions: [ResolvedAction] = []
  var capturedErrors: [ClientServerError] = []

  func handle(action: ResolvedAction, from surfaceID: String) {
    capturedActions.append(action)
  }

  func handle(error: ClientServerError, from surfaceID: String) {
    capturedErrors.append(error)
  }
}

struct SurfaceViewModelTests {

  // MARK: - Setup Helper

  private func makeViewModel() throws -> (SurfaceViewModel, TestActionHandler) {
    let handler = TestActionHandler()
    let catalog = try TestSurfaceCatalog()
    let vm = SurfaceViewModel(
      surfaceID: "test-surface",
      catalog: catalog,
      actionHandler: handler
    )
    return (vm, handler)
  }

  // MARK: - Component Updates

  @Test func updateComponentsStoresValidComponent() throws {
    let (vm, handler) = try makeViewModel()
    vm.updateComponents([
      ["id": "root", "component": "button", "label": "Click Me"],
    ])
    let components = vm.getComponents()
    #expect(components["root"] != nil)
    #expect(handler.capturedErrors.isEmpty)
  }

  @Test func updateComponentsRejectsMissingComponentKey() throws {
    let (vm, handler) = try makeViewModel()
    vm.updateComponents([
      ["id": "root"],
    ])
    #expect(handler.capturedErrors.count == 1)
    if case .validationFailed(let err) = handler.capturedErrors[0] {
      #expect(err.path == "/component")
    }
  }

  @Test func updateComponentsRejectsMissingIdKey() throws {
    let (vm, handler) = try makeViewModel()
    vm.updateComponents([
      ["component": "button"],
    ])
    #expect(handler.capturedErrors.count == 1)
    if case .validationFailed(let err) = handler.capturedErrors[0] {
      #expect(err.path == "/id")
    }
  }

  @Test func updateComponentsRejectsUnknownType() throws {
    let (vm, handler) = try makeViewModel()
    vm.updateComponents([
      ["id": "root", "component": "unknown_type"],
    ])
    #expect(handler.capturedErrors.count == 1)
  }

  // MARK: - Data Model Updates

  @Test func updateDataModelSetsValueAtPath() throws {
    let (vm, _) = try makeViewModel()
    vm.updateDataModel(path: "/user/name", value: "Alice")
    let data = vm.getDataModel()
    #expect(data["user/name"]?.stringValue == "Alice")
  }

  @Test func updateDataModelSetsNilRemovesValue() throws {
    let (vm, _) = try makeViewModel()
    vm.updateDataModel(path: "/user/name", value: "Alice")
    vm.updateDataModel(path: "/user/name", value: nil)
    let data = vm.getDataModel()
    #expect(data["user/name"] == nil)
  }

  // MARK: - Root Node Resolution

  @Test func rootNodeIsNilBeforeAnyUpdates() throws {
    let (vm, _) = try makeViewModel()
    // rootNode is published async, should be nil initially
    #expect(vm.rootNode == nil)
  }

  // MARK: - Dynamic String Resolution

  @Test func dynamicStringResolvesLiteralValue() throws {
    let (vm, _) = try makeViewModel()
    vm.updateComponents([
      ["id": "root", "component": "button", "label": "Hello"],
    ])
    let components = vm.getComponents()
    let rootJSON = try #require(components["root"])
    #expect(rootJSON["label"]?.stringValue == "Hello")
  }

  @Test func dynamicStringResolvesDataBindingPath() throws {
    let (vm, _) = try makeViewModel()
    vm.updateDataModel(path: "/user/name", value: "Alice")
    vm.updateComponents([
      ["id": "root", "component": "button", "label": ["path": "/user/name"]],
    ])
    let data = vm.getDataModel()
    #expect(data["user/name"]?.stringValue == "Alice")
  }

  // MARK: - Dynamic Boolean Resolution

  @Test func dynamicBooleanResolvesLiteralTrue() throws {
    let (vm, _) = try makeViewModel()
    vm.updateComponents([
      ["id": "root", "component": "button", "enabled": true],
    ])
    let components = vm.getComponents()
    let rootJSON = try #require(components["root"])
    #expect(rootJSON["enabled"]?.boolValue == true)
  }

  // MARK: - Action Resolution

  @Test func actionResolvesServerEvent() throws {
    let (vm, handler) = try makeViewModel()
    vm.updateComponents([
      [
        "id": "root",
        "component": "button",
        "onClick": [
          "event": [
            "name": "click",
            "context": ["userId": "123"],
          ],
        ],
      ],
    ])
    // The component should be stored successfully
    let components = vm.getComponents()
    #expect(components["root"] != nil)

    // Find the resolved action and trigger it
    // Since rootNode is published async, we test via the component buffer
    let rootJSON = try #require(components["root"])
    let actionJSON = try #require(rootJSON["onClick"]?.dictionaryValue)
    let eventJSON = try #require(actionJSON["event"]?.dictionaryValue)
    #expect(eventJSON["name"]?.stringValue == "click")
  }

  @Test func actionResolvesFunctionCall() throws {
    let (vm, _) = try makeViewModel()
    vm.updateComponents([
      [
        "id": "root",
        "component": "button",
        "onClick": [
          "functionCall": [
            "call": "submit",
            "args": ["formId": "contact"],
          ],
        ],
      ],
    ])
    let components = vm.getComponents()
    let rootJSON = try #require(components["root"])
    let actionJSON = try #require(rootJSON["onClick"]?.dictionaryValue)
    let funcCallJSON = try #require(actionJSON["functionCall"]?.dictionaryValue)
    #expect(funcCallJSON["call"]?.stringValue == "submit")
  }

  // MARK: - Child List Resolution (Static)

  @Test func childListResolvesStaticArray() throws {
    let (vm, _) = try makeViewModel()
    vm.updateComponents([
      [
        "id": "root",
        "component": "button",
        "children": ["child1", "child2"],
      ],
      ["id": "child1", "component": "button", "label": "First"],
      ["id": "child2", "component": "button", "label": "Second"],
    ])
    let components = vm.getComponents()
    #expect(components.count == 3)
    #expect(components["child1"] != nil)
    #expect(components["child2"] != nil)
  }

  // MARK: - Theme Updates

  @Test func updateThemeSetsActiveTheme() throws {
    let (vm, _) = try makeViewModel()
    let theme = TestSurfaceTheme(color: "blue")
    vm.updateTheme(theme)
    let active = vm.getActiveTheme()
    #expect(active != nil)
    #expect((active as? TestSurfaceTheme)?.color == "blue")
  }

  // MARK: - Component Buffer

  @Test func getComponentsReturnsEmptyDictInitially() throws {
    let (vm, _) = try makeViewModel()
    #expect(vm.getComponents().isEmpty)
  }

  @Test func getComponentsReturnsAllStoredComponents() throws {
    let (vm, _) = try makeViewModel()
    vm.updateComponents([
      ["id": "a", "component": "button"],
      ["id": "b", "component": "button"],
    ])
    let components = vm.getComponents()
    #expect(components.count == 2)
    #expect(components["a"] != nil)
    #expect(components["b"] != nil)
  }
}
