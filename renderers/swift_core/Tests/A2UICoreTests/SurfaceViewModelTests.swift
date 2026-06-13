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

struct SurfaceViewModelTests {
  @Test func `initialization sets properties correctly`() {
    let catalog = MockCatalog(schemas: [:])
    let handler = MockActionHandler()
    let vm = SurfaceViewModel(
      surfaceID: "surf_1",
      catalog: catalog,
      actionHandler: handler
    )

    #expect(vm.surfaceID == "surf_1")
    #expect(vm.getComponents().isEmpty)
    #expect(vm.getDataModel() == .object([:]))
    #expect(vm.getActiveTheme() == nil)
    #expect(vm.rootNode == nil)
  }

  @Test func `updateTheme updates activeTheme`() {
    let catalog = MockCatalog(schemas: [:])
    let vm = SurfaceViewModel(surfaceID: "surf_1", catalog: catalog)

    struct DummyTheme: SurfaceTheme {}
    let theme = DummyTheme()

    vm.updateTheme(theme)
    #expect(vm.getActiveTheme() != nil)
  }

  @Test func `updateDataModel updates model at path`() {
    let catalog = MockCatalog(schemas: [:])
    let vm = SurfaceViewModel(surfaceID: "surf_1", catalog: catalog)

    vm.updateDataModel(path: "/user/name", value: .string("Dave"))
    #expect(vm.getDataModel()["/user/name"] == .string("Dave"))
  }

  @Test func `updateComponents stores valid components and publishes rootNode`() async throws {
    let catalog = MockCatalog(schemas: ["container": JSONSchema(types: [.object])])
    let vm = SurfaceViewModel(surfaceID: "surf_1", catalog: catalog)

    let components: [[String: JSONValue]] = [
      [
        "id": .string("root"),
        "component": .string("container"),
        "children": .array([.string("child1")]),
      ]
    ]

    vm.updateComponents(components)

    #expect(vm.getComponents()["root"]?["component"]?.stringValue == "container")

    // Wait for main queue to execute the async update via polling
    for _ in 0..<10 {
      if vm.rootNode != nil { break }
      try await Task.sleep(nanoseconds: 10_000_000)  // 10ms
    }

    #expect(vm.rootNode?.id == "root")
  }

  @Test func `updateComponents routes ValidationError to handler and does not buffer`() {
    let ageSchema = JSONSchema(types: [.integer])
    let userSchema = JSONSchema(
      types: [.object],
      properties: ["age": ageSchema]
    )
    let catalog = MockCatalog(schemas: ["user": userSchema])
    let handler = MockActionHandler()
    let vm = SurfaceViewModel(
      surfaceID: "surf_1",
      catalog: catalog,
      actionHandler: handler
    )

    let invalidComponents: [[String: JSONValue]] = [
      [
        "id": .string("root"),
        "component": .string("user"),
        "age": .string("not_an_int"),  // Age should be integer
      ]
    ]

    vm.updateComponents(invalidComponents)

    let errors = handler.getErrors()
    #expect(errors.count == 1)
    if case .validationFailed(let validationErr) = errors.first {
      #expect(validationErr.path == "/age")
      #expect(validationErr.surfaceID == "surf_1")
    } else {
      Issue.record("Expected validationFailed error")
    }

    #expect(vm.getComponents().isEmpty)
  }

  @Test func `updateComponents routes error when component or id is missing`() {
    let catalog = MockCatalog(schemas: [:])
    let handler = MockActionHandler()
    let vm = SurfaceViewModel(
      surfaceID: "surf_1",
      catalog: catalog,
      actionHandler: handler
    )

    // Missing 'component'
    let missingComponent: [[String: JSONValue]] = [
      [
        "id": .string("root")
      ]
    ]
    vm.updateComponents(missingComponent)

    // Missing 'id'
    let missingID: [[String: JSONValue]] = [
      [
        "component": .string("button")
      ]
    ]
    vm.updateComponents(missingID)

    let errors = handler.getErrors()
    #expect(errors.count == 2)

    if case .validationFailed(let firstErr) = errors.first {
      #expect(firstErr.path == "/component")
      #expect(firstErr.message == "Missing required key 'component'")
    } else {
      Issue.record("Expected validationFailed error for missing component")
    }

    if case .validationFailed(let secondErr) = errors.last {
      #expect(secondErr.path == "/id")
      #expect(secondErr.message == "Missing required key 'id'")
    } else {
      Issue.record("Expected validationFailed error for missing id")
    }

    #expect(vm.getComponents().isEmpty)
  }

  @Test func `updateComponents routes error when component type is unregistered`() {
    let catalog = MockCatalog(schemas: [:])
    let handler = MockActionHandler()
    let vm = SurfaceViewModel(
      surfaceID: "surf_1",
      catalog: catalog,
      actionHandler: handler
    )

    let unregisteredComponents: [[String: JSONValue]] = [
      [
        "id": .string("root"),
        "component": .string("UnknownComponent"),
      ]
    ]

    vm.updateComponents(unregisteredComponents)

    let errors = handler.getErrors()
    #expect(errors.count == 1)

    if case .validationFailed(let error) = errors.first {
      #expect(error.path == "/component")
      #expect(
        error.message
          == "Unknown component type 'UnknownComponent' not registered in catalog"
      )
    } else {
      Issue.record("Expected validationFailed error for unregistered component type")
    }

    #expect(vm.getComponents().isEmpty)
  }

  // MARK: - Additional Comprehensive Integration Tests

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

  private struct DoubleFunction: LocalFunction {
    func evaluate(arguments: [String: JSONValue]) throws -> JSONValue {
      guard let val = arguments["val"]?.doubleValue else {
        return .null
      }
      return .number(val * 2)
    }
  }

  private struct TestCatalog: ComponentCatalog {
    let schemas: [String: JSONSchema]
    let functions: [String: any LocalFunction]

    func schema(forType type: String) -> JSONSchema? {
      schemas[type]
    }

    struct MockTheme: SurfaceTheme {}
    func makeTheme(jsonObject: JSONValue) -> (any SurfaceTheme)? {
      MockTheme()
    }

    func localFunction(for name: String) -> (any LocalFunction)? {
      functions[name]
    }
  }

  @Test func `classifySchema handles oneOf anyOf allOf and nested refs`() async throws {
    registerCommonSchemas()
    let dynamicBoolSchema = JSONSchema(
      types: [.object],
      properties: [
        "value": JSONSchema(
          allOf: [
            JSONSchema(booleanSchema: true),
            JSONSchema(
              anyOf: [
                JSONSchema(
                  oneOf: [
                    JSONSchema(
                      types: [.object],
                      ref: "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/DynamicBoolean"
                    )
                  ]
                )
              ]
            ),
          ]
        )
      ]
    )

    let catalog = TestCatalog(schemas: ["custom": dynamicBoolSchema], functions: [:])
    let handler = MockActionHandler()
    let vm = SurfaceViewModel(surfaceID: "surf_1", catalog: catalog, actionHandler: handler)

    let components: [[String: JSONValue]] = [
      [
        "id": .string("root"),
        "component": .string("custom"),
        "value": .object(["path": .string("profile.active")]),
      ]
    ]
    vm.updateComponents(components)

    // Wait for main queue to execute the async update via polling
    for _ in 0..<20 {
      if vm.rootNode != nil { break }
      try await Task.sleep(nanoseconds: 10_000_000)  // 10ms
    }

    if let root = vm.rootNode {
      let resolvedProp = root.properties["value"]
      #expect(resolvedProp is DataBinding<Bool>)
    } else {
      Issue.record("Expected rootNode to be resolved. Errors: \(handler.getErrors())")
    }
  }

  @Test func `evaluateDynamicValue evaluates local functions and nested functions`() async throws {
    registerCommonSchemas()
    let doubleFn = DoubleFunction()
    let catalog = TestCatalog(
      schemas: [
        "custom": JSONSchema(
          types: [.object],
          properties: [
            "val": JSONSchema(
              ref: "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/DynamicNumber")
          ]
        )
      ],
      functions: ["double": doubleFn]
    )
    let handler = MockActionHandler()
    let vm = SurfaceViewModel(surfaceID: "surf_1", catalog: catalog, actionHandler: handler)

    vm.updateDataModel(path: "/count", value: .number(5.0))

    let components: [[String: JSONValue]] = [
      [
        "id": .string("root"),
        "component": .string("custom"),
        "val": .object([
          "call": .string("double"),
          "args": .object([
            "val": .object(["path": .string("/count")])
          ]),
        ]),
      ]
    ]
    vm.updateComponents(components)

    // Wait for main queue to execute the async update via polling
    for _ in 0..<20 {
      if vm.rootNode != nil { break }
      try await Task.sleep(nanoseconds: 10_000_000)  // 10ms
    }

    if let root = vm.rootNode, let binding = root.properties["val"] as? DataBinding<Double> {
      #expect(binding.get() == 10.0)
    } else {
      Issue.record(
        "Expected DataBinding<Double> to be resolved. Errors: \(handler.getErrors())"
      )
    }
  }

  @Test func `resolveAction resolves event and function actions and triggers correctly`()
    async throws
  {
    registerCommonSchemas()
    let handler = MockActionHandler()
    let catalog = TestCatalog(
      schemas: [
        "button": JSONSchema(
          types: [.object],
          properties: [
            "onClick": JSONSchema(
              ref: "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/Action")
          ]
        )
      ],
      functions: [:]
    )
    let vm = SurfaceViewModel(surfaceID: "surf_1", catalog: catalog, actionHandler: handler)
    vm.updateDataModel(path: "/username", value: .string("Alice"))

    let components: [[String: JSONValue]] = [
      [
        "id": .string("root"),
        "component": .string("button"),
        "onClick": .object([
          "event": .object([
            "name": .string("click_event"),
            "context": .object([
              "user": .object(["path": .string("/username")]),
              "static": .string("hello"),
            ]),
          ])
        ]),
      ]
    ]
    vm.updateComponents(components)

    // Wait for main queue to execute the async update via polling
    for _ in 0..<20 {
      if vm.rootNode != nil { break }
      try await Task.sleep(nanoseconds: 10_000_000)  // 10ms
    }

    guard let root = vm.rootNode, let action = root.properties["onClick"] as? ResolvedAction else {
      Issue.record("Expected resolved onClick action. Errors: \(handler.getErrors())")
      return
    }

    action()

    let actions = handler.getActions()
    #expect(actions.count == 1)
    if let firstAction = actions.first {
      if case .event(let name, let context) = firstAction.identity {
        #expect(name == "click_event")
        #expect(context?["user"] == .string("Alice"))
        #expect(context?["static"] == .string("hello"))
      } else {
        Issue.record("Expected event action identity")
      }
    }
  }

  @Test func `resolveChildList resolves array of ids and template expansions`() async throws {
    registerCommonSchemas()
    let catalog = TestCatalog(
      schemas: [
        "list": JSONSchema(
          types: [.object],
          properties: [
            "children": JSONSchema(
              ref: "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/ChildList")
          ]
        ),
        "item": JSONSchema(
          types: [.object],
          properties: [
            "title": JSONSchema(
              ref: "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/DynamicString")
          ]
        ),
      ],
      functions: [:]
    )
    let handler = MockActionHandler()
    let vm = SurfaceViewModel(surfaceID: "surf_1", catalog: catalog, actionHandler: handler)

    vm.updateDataModel(
      path: "/todos",
      value: .array([
        .object(["name": .string("Buy milk")]),
        .object(["name": .string("Clean room")]),
      ])
    )

    let components: [[String: JSONValue]] = [
      [
        "id": .string("root"),
        "component": .string("list"),
        "children": .object([
          "template": .string("item_template"),
          "path": .string("/todos"),
        ]),
      ],
      [
        "id": .string("item_template"),
        "component": .string("item"),
        "title": .object(["path": .string("name")]),
      ],
    ]
    vm.updateComponents(components)

    // Wait for main queue to execute the async update via polling
    for _ in 0..<20 {
      if vm.rootNode != nil { break }
      try await Task.sleep(nanoseconds: 10_000_000)  // 10ms
    }

    guard let root = vm.rootNode, let children = root.properties["children"] as? [Node] else {
      Issue.record("Expected resolved children list. Errors: \(handler.getErrors())")
      return
    }

    #expect(children.count == 2)
    #expect(children[0].id == "item_template_0")
    #expect(children[0].type == "item")
    #expect(children[1].id == "item_template_1")
    #expect(children[1].type == "item")

    if let titleBinding = children[0].properties["title"] as? DataBinding<String> {
      #expect(titleBinding.get() == "Buy milk")
    } else {
      Issue.record("Expected title to be DataBinding<String>")
    }

    if let titleBinding2 = children[1].properties["title"] as? DataBinding<String> {
      #expect(titleBinding2.get() == "Clean room")
    } else {
      Issue.record("Expected title to be DataBinding<String>")
    }
  }

  @Test func `resolveChildList resolves simple array of child ids`() async throws {
    registerCommonSchemas()
    let catalog = TestCatalog(
      schemas: [
        "list": JSONSchema(
          types: [.object],
          properties: [
            "children": JSONSchema(
              ref: "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/ChildList")
          ]
        ),
        "item": JSONSchema(types: [.object]),
      ],
      functions: [:]
    )
    let handler = MockActionHandler()
    let vm = SurfaceViewModel(surfaceID: "surf_1", catalog: catalog, actionHandler: handler)

    let components: [[String: JSONValue]] = [
      [
        "id": .string("root"),
        "component": .string("list"),
        "children": .array([.string("child_1"), .string("child_2")]),
      ],
      [
        "id": .string("child_1"),
        "component": .string("item"),
      ],
      [
        "id": .string("child_2"),
        "component": .string("item"),
      ],
    ]
    vm.updateComponents(components)

    // Wait for main queue to execute the async update via polling
    for _ in 0..<20 {
      if vm.rootNode != nil { break }
      try await Task.sleep(nanoseconds: 10_000_000)  // 10ms
    }

    guard let root = vm.rootNode, let children = root.properties["children"] as? [Node] else {
      Issue.record("Expected resolved children list. Errors: \(handler.getErrors())")
      return
    }

    #expect(children.count == 2)
    #expect(children[0].id == "child_1")
    #expect(children[1].id == "child_2")
  }

  @Test func `two-way binding set updates dataModel and triggers rebuild`() async throws {
    registerCommonSchemas()
    let catalog = TestCatalog(
      schemas: [
        "input": JSONSchema(
          types: [.object],
          properties: [
            "text": JSONSchema(
              ref: "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/DynamicString"),
            "checked": JSONSchema(
              ref: "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/DynamicBoolean"),
            "count": JSONSchema(
              ref: "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/DynamicNumber"),
            "generic": JSONSchema(
              ref: "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/DynamicValue"),
          ]
        )
      ],
      functions: [:]
    )
    let vm = SurfaceViewModel(surfaceID: "surf_1", catalog: catalog)
    vm.updateDataModel(path: "/textVal", value: .string("hello"))
    vm.updateDataModel(path: "/boolVal", value: .boolean(false))
    vm.updateDataModel(path: "/numVal", value: .number(10.0))
    vm.updateDataModel(path: "/genVal", value: .array([.string("a")]))

    let components: [[String: JSONValue]] = [
      [
        "id": .string("root"),
        "component": .string("input"),
        "text": .object(["path": .string("/textVal")]),
        "checked": .object(["path": .string("/boolVal")]),
        "count": .object(["path": .string("/numVal")]),
        "generic": .object(["path": .string("/genVal")]),
      ]
    ]
    vm.updateComponents(components)

    for _ in 0..<20 {
      if vm.rootNode != nil { break }
      try await Task.sleep(nanoseconds: 10_000_000)
    }

    guard let root = vm.rootNode else {
      Issue.record("Expected rootNode to be resolved")
      return
    }

    guard let textBinding = root.properties["text"] as? DataBinding<String>,
      let checkedBinding = root.properties["checked"] as? DataBinding<Bool>,
      let countBinding = root.properties["count"] as? DataBinding<Double>,
      let genericBinding = root.properties["generic"] as? DataBinding<JSONValue>
    else {
      Issue.record("Expected all dynamic bindings to be resolved")
      return
    }

    // Set new values and verify they propagate to the dataModel
    textBinding.set("world")
    checkedBinding.set(true)
    countBinding.set(42.0)
    genericBinding.set(.string("dynamic"))

    #expect(vm.getDataModel()["/textVal"] == .string("world"))
    #expect(vm.getDataModel()["/boolVal"] == .boolean(true))
    #expect(vm.getDataModel()["/numVal"] == .number(42.0))
    #expect(vm.getDataModel()["/genVal"] == .string("dynamic"))

    // Wait for main queue to execute the async rebuild
    for _ in 0..<20 {
      if let newRoot = vm.rootNode,
        let newText = newRoot.properties["text"] as? DataBinding<String>,
        newText.get() == "world"
      {
        break
      }
      try await Task.sleep(nanoseconds: 10_000_000)
    }

    // Verify bindings now get the updated values from the rebuilt tree
    if let newRoot = vm.rootNode {
      #expect((newRoot.properties["text"] as? DataBinding<String>)?.get() == "world")
      #expect((newRoot.properties["checked"] as? DataBinding<Bool>)?.get() == true)
      #expect((newRoot.properties["count"] as? DataBinding<Double>)?.get() == 42.0)
      #expect(
        (newRoot.properties["generic"] as? DataBinding<JSONValue>)?.get() == .string("dynamic"))
    } else {
      Issue.record("Expected rebuilt rootNode")
    }
  }

  @Test func `resolveAction resolves functionCall action and triggers with evaluated arguments`()
    async throws
  {
    registerCommonSchemas()
    let handler = MockActionHandler()
    let catalog = TestCatalog(
      schemas: [
        "button": JSONSchema(
          types: [.object],
          properties: [
            "onClick": JSONSchema(
              ref: "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/Action")
          ]
        )
      ],
      functions: [:]
    )
    let vm = SurfaceViewModel(surfaceID: "surf_1", catalog: catalog, actionHandler: handler)
    vm.updateDataModel(path: "/username", value: .string("Bob"))

    let components: [[String: JSONValue]] = [
      [
        "id": .string("root"),
        "component": .string("button"),
        "onClick": .object([
          "functionCall": .object([
            "call": .string("say_hello"),
            "args": .object([
              "user": .object(["path": .string("/username")]),
              "greeting": .string("hi"),
            ]),
          ])
        ]),
      ]
    ]
    vm.updateComponents(components)

    for _ in 0..<20 {
      if vm.rootNode != nil { break }
      try await Task.sleep(nanoseconds: 10_000_000)
    }

    guard let root = vm.rootNode, let action = root.properties["onClick"] as? ResolvedAction else {
      Issue.record("Expected resolved onClick action")
      return
    }

    action()

    let actions = handler.getActions()
    #expect(actions.count == 1)
    if let firstAction = actions.first {
      if case .function(let call, let args) = firstAction.identity {
        #expect(call == "say_hello")
        #expect(args?["user"] == .string("Bob"))
        #expect(args?["greeting"] == .string("hi"))
      } else {
        Issue.record("Expected functionCall action identity")
      }
    }
  }
}
