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
import A2UISwiftUI
import Foundation
import JSONSchema
import SwiftUI
import Testing

@MainActor struct IntegrationTests {

  // Thread-safe state container for testing
  private final class TestStateBox<T: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var _value: T

    init(_ value: T) {
      self._value = value
    }

    var value: T {
      lock.withLock { _value }
    }

    func mutate(_ block: (inout T) -> Void) {
      lock.withLock { block(&_value) }
    }
  }

  // Helper to find a node by ID in the resolved component tree
  private func findNode(id: String, in node: Node?) -> Node? {
    guard let node else { return nil }
    if node.id == id { return node }
    for child in node.children {
      if let found = findNode(id: id, in: child) {
        return found
      }
    }
    return nil
  }

  // Helper to register common schemas for proper property classification
  private func registerCommonSchemas() {
    let commonURL = URL(string: "https://a2ui.org/schemas/v0_9_1/common.json")!
    JSONSchema.dynamicRegistry[commonURL] = JSONSchema(
      id: "https://a2ui.org/schemas/v0_9_1/common.json",
      defs: [
        "DynamicBoolean": JSONSchema(types: [.object, .boolean]),
        "DynamicNumber": JSONSchema(types: [.object, .integer, .number]),
        "DynamicString": JSONSchema(types: [.object, .string]),
        "DynamicValue": JSONSchema(types: [.object, .string, .integer, .number, .boolean]),
        "Action": JSONSchema(types: [.object]),
        "ChildList": JSONSchema(types: [.object, .array]),
      ]
    )
  }

  // MARK: - Tier 3: Cross-Feature Combinations

  @Test func `Combination of data binding and actions resolves and triggers successfully`()
    async throws
  {
    registerCommonSchemas()

    let catalog = MockComponentCatalog()

    // We want a button that, when tapped, increments a counter in the data model.
    // The counter is bound to a text node that displays the count.
    let handler = MockActionHandler()
    let vm = SurfaceViewModel(surfaceID: "comb_1", catalog: catalog, actionHandler: handler)

    // Set initial data model (using string because Text component expects string values)
    vm.updateDataModel(path: "/counter", value: .string("0"))

    let components: [[String: JSONValue]] = [
      [
        "id": .string("root"),
        "component": .string("VStack"),
        "children": .array([.string("btn"), .string("lbl")]),
      ],
      [
        "id": .string("btn"),
        "component": .string("Button"),
        "label": .string("Increment"),
        "onClick": .object([
          "functionCall": .object([
            "call": .string("incrementCounter"),
            "args": .object([:]),
          ])
        ]),
      ],
      [
        "id": .string("lbl"),
        "component": .string("Text"),
        "text": .object([
          "type": .string("path"),
          "path": .string("/counter"),
        ]),
      ],
    ]

    vm.updateComponents(components)

    for _ in 0..<10 {
      if vm.rootNode != nil { break }
      try await Task.sleep(nanoseconds: 10_000_000)
    }

    let root = vm.rootNode
    #expect(root != nil)

    // Verify initial label value
    let lblNode = findNode(id: "lbl", in: vm.rootNode)
    #expect(lblNode != nil)
    let textBinding = lblNode?.properties["text"] as? DataBinding<String>
    #expect(textBinding?.get() == "0")

    // Simulate button tap by triggering the action
    let btnNode = findNode(id: "btn", in: vm.rootNode)
    #expect(btnNode != nil)
    let action = btnNode?.properties["onClick"] as? ResolvedAction
    #expect(action != nil)

    // Trigger action
    action?()

    // Mock the action handler's behavior: when incrementCounter is called, update the model
    #expect(handler.triggeredActions.count == 1)
    vm.updateDataModel(path: "/counter", value: .string("1"))

    // Verify that the label binding now reflects the updated value
    #expect(textBinding?.get() == "1")
  }

  // MARK: - Tier 4: Real-World Scenarios

  @Test func `Multi-step form with live validation scenario executes successfully`()
    async throws
  {
    registerCommonSchemas()

    let catalog = MockComponentCatalog()

    let handler = MockActionHandler()
    let vm = SurfaceViewModel(surfaceID: "form_1", catalog: catalog, actionHandler: handler)

    // Initial form state
    vm.updateDataModel(path: "/email", value: .string(""))
    vm.updateDataModel(path: "/emailError", value: .string(""))

    let components: [[String: JSONValue]] = [
      [
        "id": .string("root"),
        "component": .string("VStack"),
        "children": .array([.string("email_input"), .string("error_lbl")]),
      ],
      [
        "id": .string("email_input"),
        "component": .string("Input"),
        "value": .object([
          "type": .string("path"),
          "path": .string("/email"),
        ]),
      ],
      [
        "id": .string("error_lbl"),
        "component": .string("Text"),
        "text": .object([
          "type": .string("path"),
          "path": .string("/emailError"),
        ]),
      ],
    ]

    vm.updateComponents(components)

    for _ in 0..<10 {
      if vm.rootNode != nil { break }
      try await Task.sleep(nanoseconds: 10_000_000)
    }

    let emailNode = findNode(id: "email_input", in: vm.rootNode)
    let errorNode = findNode(id: "error_lbl", in: vm.rootNode)
    #expect(emailNode != nil)
    #expect(errorNode != nil)

    let emailBinding = emailNode?.properties["value"] as? DataBinding<String>
    let errorBinding = errorNode?.properties["text"] as? DataBinding<String>

    #expect(emailBinding?.get() == "")
    #expect(errorBinding?.get() == "")

    // Simulate user typing invalid email
    emailBinding?.swiftUI.wrappedValue = "invalid-email"
    #expect(vm.getDataModel()["/email"]?.stringValue == "invalid-email")

    // Live validation (handled by server/agent side, simulated here)
    vm.updateDataModel(path: "/emailError", value: .string("Invalid email format"))

    // Verify that the error label binding now reactively shows the validation error
    #expect(errorBinding?.get() == "Invalid email format")

    // Simulate user correcting email
    emailBinding?.swiftUI.wrappedValue = "user@a2ui.org"
    #expect(vm.getDataModel()["/email"]?.stringValue == "user@a2ui.org")

    vm.updateDataModel(path: "/emailError", value: .string(""))
    #expect(errorBinding?.get() == "")
  }
}
