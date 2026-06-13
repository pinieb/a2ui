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
import Foundation
import JSONSchema
import Testing

struct ResolutionTests {
  // Nested Mock Catalog supporting local functions
  struct CustomMockCatalog: ComponentCatalog {
    let schemas: [String: JSONSchema]
    let functions: [String: any LocalFunction]

    func schema(forType type: String) -> JSONSchema? {
      schemas[type]
    }

    func makeTheme(jsonObject: JSONValue) -> (any SurfaceTheme)? {
      nil
    }

    func localFunction(for name: String) -> (any LocalFunction)? {
      functions[name]
    }
  }

  // Nested Mock Function
  struct MockAddFunction: LocalFunction {
    func evaluate(arguments: [String: JSONValue]) throws -> JSONValue {
      guard let a = arguments["a"]?.doubleValue,
        let b = arguments["b"]?.doubleValue
      else {
        return .null
      }
      return .number(a + b)
    }
  }

  @Test func `literal and path-based dynamic values`() async throws {
    let boolSchema = JSONSchema(ref: "common_types.json#/$defs/DynamicBoolean")
    let stringSchema = JSONSchema(ref: "common_types.json#/$defs/DynamicString")
    let numberSchema = JSONSchema(ref: "common_types.json#/$defs/DynamicNumber")
    let valueSchema = JSONSchema(ref: "common_types.json#/$defs/DynamicValue")

    let compSchema = JSONSchema(
      types: [.object],
      properties: [
        "isCool": boolSchema,
        "title": stringSchema,
        "score": numberSchema,
        "config": valueSchema,
      ]
    )

    let catalog = CustomMockCatalog(
      schemas: ["Card": compSchema],
      functions: [:]
    )

    let vm = SurfaceViewModel(surfaceID: "surf_1", catalog: catalog)

    let components: [[String: JSONValue]] = [
      [
        "id": .string("root"),
        "component": .string("Card"),
        "isCool": .object(["path": .string("/user/cool")]),
        "title": .string("Static Title"),
        "score": .object(["path": .string("/user/score")]),
        "config": .object(["path": .string("/user/config")]),
      ]
    ]

    // Set initial data model values
    vm.updateDataModel(path: "/user/cool", value: .boolean(true))
    vm.updateDataModel(path: "/user/score", value: .number(99.5))
    vm.updateDataModel(
      path: "/user/config",
      value: .object(["theme": .string("dark")])
    )

    vm.updateComponents(components)

    // Wait for async tree rebuild
    for _ in 0..<10 {
      if vm.rootNode != nil { break }
      try await Task.sleep(nanoseconds: 10_000_000)
    }

    guard let root = vm.rootNode else {
      Issue.record("Root node was not resolved")
      return
    }

    #expect(root.id == "root")
    #expect(root.type == "Card")

    // Verify properties
    guard let isCoolBinding = root.properties["isCool"] as? DataBinding<Bool>,
      let titleBinding = root.properties["title"] as? DataBinding<String>,
      let scoreBinding = root.properties["score"] as? DataBinding<Double>,
      let configBinding = root.properties["config"] as? DataBinding<JSONValue>
    else {
      Issue.record("Failed to resolve dynamic properties to bindings")
      return
    }

    #expect(isCoolBinding.get() == true)
    #expect(titleBinding.get() == "Static Title")
    #expect(scoreBinding.get() == 99.5)
    #expect(configBinding.get()["theme"]?.stringValue == "dark")
  }

  @Test func `two-way binding updates data model and rebuilds tree`() async throws {
    let boolSchema = JSONSchema(ref: "common_types.json#/$defs/DynamicBoolean")
    let compSchema = JSONSchema(
      types: [.object],
      properties: ["isEnabled": boolSchema]
    )

    let catalog = CustomMockCatalog(schemas: ["Toggle": compSchema], functions: [:])
    let vm = SurfaceViewModel(surfaceID: "surf_1", catalog: catalog)

    let components: [[String: JSONValue]] = [
      [
        "id": .string("root"),
        "component": .string("Toggle"),
        "isEnabled": .object(["path": .string("/settings/enabled")]),
      ]
    ]

    vm.updateDataModel(path: "/settings/enabled", value: .boolean(false))
    vm.updateComponents(components)

    for _ in 0..<10 {
      if vm.rootNode != nil { break }
      try await Task.sleep(nanoseconds: 10_000_000)
    }

    guard let root = vm.rootNode,
      let isEnabledBinding = root.properties["isEnabled"] as? DataBinding<Bool>
    else {
      Issue.record("Failed to resolve isEnabled binding")
      return
    }

    #expect(isEnabledBinding.get() == false)

    // Modify binding - should update data model and trigger rebuild
    isEnabledBinding.set(true)

    // Wait for rebuild
    try await Task.sleep(nanoseconds: 20_000_000)

    #expect(vm.getDataModel()["/settings/enabled"] == .boolean(true))

    guard let updatedRoot = vm.rootNode,
      let updatedBinding = updatedRoot.properties["isEnabled"] as? DataBinding<Bool>
    else {
      Issue.record("Failed to resolve updated binding")
      return
    }
    #expect(updatedBinding.get() == true)
  }

  @Test func `local function evaluation`() async throws {
    let numberSchema = JSONSchema(ref: "common_types.json#/$defs/DynamicNumber")
    let compSchema = JSONSchema(
      types: [.object],
      properties: ["total": numberSchema]
    )

    let catalog = CustomMockCatalog(
      schemas: ["Calc": compSchema],
      functions: ["add": MockAddFunction()]
    )
    let vm = SurfaceViewModel(surfaceID: "surf_1", catalog: catalog)

    let components: [[String: JSONValue]] = [
      [
        "id": .string("root"),
        "component": .string("Calc"),
        "total": .object([
          "call": .string("add"),
          "args": .object([
            "a": .object(["path": .string("/val1")]),
            "b": .object([
              "call": .string("add"),
              "args": .object([
                "a": .number(5),
                "b": .number(10),
              ]),
            ]),
          ]),
        ]),
      ]
    ]

    vm.updateDataModel(path: "/val1", value: .number(2.5))
    vm.updateComponents(components)

    for _ in 0..<10 {
      if vm.rootNode != nil { break }
      try await Task.sleep(nanoseconds: 10_000_000)
    }

    guard let root = vm.rootNode,
      let totalBinding = root.properties["total"] as? DataBinding<Double>
    else {
      Issue.record("Failed to resolve total binding")
      return
    }

    // Expected: 2.5 + (5 + 10) = 17.5
    #expect(totalBinding.get() == 17.5)

    // Update val1, verify total evaluates to new value
    vm.updateDataModel(path: "/val1", value: .number(5.0))
    try await Task.sleep(nanoseconds: 20_000_000)

    // Expected: 5.0 + 15.0 = 20.0
    #expect(totalBinding.get() == 20.0)
  }

  @Test func `action triggering evaluates dynamic context and forwards event`() async throws {
    let actionSchema = JSONSchema(ref: "common_types.json#/$defs/Action")
    let compSchema = JSONSchema(
      types: [.object],
      properties: ["submit": actionSchema]
    )

    let catalog = CustomMockCatalog(schemas: ["Form": compSchema], functions: [:])
    let handler = MockActionHandler()
    let vm = SurfaceViewModel(
      surfaceID: "surf_1",
      catalog: catalog,
      actionHandler: handler
    )

    let components: [[String: JSONValue]] = [
      [
        "id": .string("root"),
        "component": .string("Form"),
        "submit": .object([
          "event": .object([
            "name": .string("onSubmit"),
            "context": .object([
              "user": .object(["path": .string("/user/name")]),
              "mode": .string("advanced"),
            ]),
          ])
        ]),
      ]
    ]

    vm.updateDataModel(path: "/user/name", value: .string("Alice"))
    vm.updateComponents(components)

    for _ in 0..<10 {
      if vm.rootNode != nil { break }
      try await Task.sleep(nanoseconds: 10_000_000)
    }

    guard let root = vm.rootNode,
      let submitAction = root.properties["submit"] as? ResolvedAction
    else {
      Issue.record("Failed to resolve submit action")
      return
    }

    #expect(handler.getActions().isEmpty)

    // Trigger the action
    submitAction()

    let actions = handler.getActions()
    #expect(actions.count == 1)

    guard let triggeredAction = actions.first else { return }

    // Verify it evaluates dynamic context at trigger time
    if case .event(let name, let context) = triggeredAction.identity {
      #expect(name == "onSubmit")
      #expect(context?["user"] == .string("Alice"))
      #expect(context?["mode"] == .string("advanced"))
    } else {
      Issue.record("Expected event-style action identity")
    }
  }
}
