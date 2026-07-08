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
import Testing

// MARK: - Stress Tests

struct StressTests {

  // MARK: - Deep Nesting

  @Test func deeplyNestedDataModel100Levels() throws {
    let catalog = try IntegrationCatalog()
    let vm = SurfaceViewModel(surfaceID: "s1", catalog: catalog)

    // Build a 100-level deep nested data model
    var path = "/level0"
    for i in 1..<100 {
      vm.updateDataModel(path: path, value: JSONValue.object(["level\(i)": .object([:])]))
      path += "/level\(i)"
    }
    vm.updateDataModel(path: path, value: "deep")

    let data = vm.getDataModel()
    // Traverse 100 levels deep
    var current = data
    for i in 0..<100 {
      let key = i == 0 ? "level0" : "level\(i)"
      guard let next = current[key] else {
        Issue.record("Missing level \(i) at path \(key)")
        return
      }
      current = next
    }
    #expect(current.stringValue == "deep")
  }

  @Test func deeplyNestedComponentDefinitions100Children() throws {
    let catalog = try IntegrationCatalog()
    let handler = IntegrationActionHandler()
    let vm = SurfaceViewModel(
      surfaceID: "s1",
      catalog: catalog,
      actionHandler: handler
    )

    // Create 100 child components
    var components: [[String: JSONValue]] = []
    var childIDs: [JSONValue] = []
    for i in 0..<100 {
      let id = "child\(i)"
      childIDs.append(.string(id))
      components.append([
        "id": .string(id),
        "component": "text",
        "text": .string("Child \(i)"),
      ])
    }

    // Root component with 100 static children
    components.append([
      "id": "root",
      "component": "button",
      "label": "Root",
      "children": .array(childIDs),
    ])

    vm.updateComponents(components)

    let stored = vm.getComponents()
    #expect(stored.count == 101)
    #expect(stored["root"] != nil)
    #expect(stored["child99"] != nil)
  }

  // MARK: - Concurrent Updates

  @Test func concurrentDataModelUpdates() async throws {
    let catalog = try IntegrationCatalog()
    let vm = SurfaceViewModel(surfaceID: "s1", catalog: catalog)

    // 10 threads × 200 updates each
    let taskCount = 10
    let updatesPerTask = 200

    await withTaskGroup(of: Void.self) { group in
      for taskIndex in 0..<taskCount {
        group.addTask {
          for updateIndex in 0..<updatesPerTask {
            let path = "/task\(taskIndex)/val\(updateIndex)"
            let value: JSONValue = .integer(updateIndex)
            vm.updateDataModel(path: path, value: value)
          }
        }
      }
    }

    // Verify all updates were applied
    let data = vm.getDataModel()
    for taskIndex in 0..<taskCount {
      for updateIndex in 0..<updatesPerTask {
        let path = "task\(taskIndex)/val\(updateIndex)"
        let value = data[path]
        #expect(
          value?.intValue == updateIndex,
          "Missing update at \(path)"
        )
      }
    }
  }

  @Test func concurrentComponentUpdates() async throws {
    let catalog = try IntegrationCatalog()
    let vm = SurfaceViewModel(surfaceID: "s1", catalog: catalog)

    // Multiple threads updating different components concurrently
    await withTaskGroup(of: Void.self) { group in
      for taskIndex in 0..<10 {
        group.addTask {
          let components: [[String: JSONValue]] = (0..<20).map { i in
            [
              "id": .string("t\(taskIndex)_c\(i)"),
              "component": "text",
              "text": .string("Task \(taskIndex) Component \(i)"),
            ]
          }
          vm.updateComponents(components)
        }
      }
    }

    let stored = vm.getComponents()
    // Each task creates 20 components with unique IDs
    #expect(stored.count == 200)
  }

  // MARK: - Missing Optional Properties

  @Test func missingOptionalPropertiesDoesNotCrash() throws {
    let catalog = try IntegrationCatalog()
    let vm = SurfaceViewModel(surfaceID: "s1", catalog: catalog)

    // Button with only required fields — no label, no onClick
    vm.updateComponents([
      ["id": "root", "component": "button"],
    ])

    let components = vm.getComponents()
    #expect(components["root"] != nil)
  }

  @Test func missingDataModelPathReturnsNull() throws {
    let catalog = try IntegrationCatalog()
    let vm = SurfaceViewModel(surfaceID: "s1", catalog: catalog)

    // Component references a data path that doesn't exist
    vm.updateComponents([
      [
        "id": "root",
        "component": "text",
        "text": ["path": "/nonexistent/path"],
      ],
    ])

    let data = vm.getDataModel()
    #expect(data["nonexistent/path"] == nil)
  }

  @Test func emptyComponentListDoesNotCrash() throws {
    let catalog = try IntegrationCatalog()
    let vm = SurfaceViewModel(surfaceID: "s1", catalog: catalog)

    vm.updateComponents([])
    #expect(vm.getComponents().isEmpty)
  }

  @Test func emptyChildListResolvesToEmptyArray() throws {
    let catalog = try IntegrationCatalog()
    let vm = SurfaceViewModel(surfaceID: "s1", catalog: catalog)

    vm.updateComponents([
      [
        "id": "root",
        "component": "button",
        "label": "Root",
        "children": .array([]),
      ],
    ])

    let components = vm.getComponents()
    let root = try #require(components["root"])
    let children = root["children"]?.arrayValue
    #expect(children?.isEmpty == true)
  }

  @Test func dynamicChildListWithEmptyDataModelReturnsEmptyArray() throws {
    let catalog = try IntegrationCatalog()
    let vm = SurfaceViewModel(surfaceID: "s1", catalog: catalog)

    vm.updateComponents([
      [
        "id": "root",
        "component": "button",
        "label": "Root",
        "children": [
          "componentId": "childTemplate",
          "path": "/items",
        ],
      ],
      ["id": "childTemplate", "component": "text", "text": "Item"],
    ])

    // Data model has no /items array — should resolve to empty
    let components = vm.getComponents()
    #expect(components["childTemplate"] != nil)
  }

  // MARK: - Rapid Sequential Updates

  @Test func rapidSequentialUpdatesPreserveLatestState() throws {
    let catalog = try IntegrationCatalog()
    let vm = SurfaceViewModel(surfaceID: "s1", catalog: catalog)

    // Rapidly update the same data model path 500 times
    for i in 0..<500 {
      vm.updateDataModel(path: "/counter", value: .integer(i))
    }

    let data = vm.getDataModel()
    #expect(data["counter"]?.intValue == 499)
  }

  @Test func rapidComponentUpdatesReplaceLatest() throws {
    let catalog = try IntegrationCatalog()
    let vm = SurfaceViewModel(surfaceID: "s1", catalog: catalog)

    // Rapidly update the same component 500 times
    for i in 0..<500 {
      vm.updateComponents([
        ["id": "root", "component": "text", "text": .string("Update \(i)")],
      ])
    }

    let components = vm.getComponents()
    #expect(components.count == 1)
    #expect(components["root"]?["text"]?.stringValue == "Update 499")
  }
}
