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

@MainActor
struct StressTests {

  // MARK: - Deep Nesting

  @Test func deeplyNestedDataModel100Levels() throws {
    let catalog = BasicCatalog.v091Catalog
    let vm = SurfaceViewModel(surfaceID: "s1", catalogs: [catalog.id: catalog])

    // Build a 100-level deep nested data model
    var path = "/level0"
    for i in 1..<100 {
      vm.dataModel.set(path, value: JSONValue.object(["level\(i)": .object([:])]))
      path += "/level\(i)"
    }
    vm.dataModel.set(path, value: "deep")

    let data = vm.dataModel.data
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
    let catalog = BasicCatalog.v091Catalog
    let processor = MessageProcessor(catalogs: [catalog.id: catalog])

    try processor.process(
      line: """
        {"version": "v0.9.1", "createSurface": {"surfaceId": "s1", "catalogId": "\(catalog.id)"}}
        """)

    var componentsJSON = "["
    for i in 0..<100 {
      componentsJSON += """
        {"id": "child\(i)", "component": "Text", "text": "Child \(i)"},
        """
    }
    let childIDs = (0..<100).map { "\"child\($0)\"" }.joined(separator: ",")
    componentsJSON += """
      {"id": "root", "component": "Column", "children": [\(childIDs)]}
      ]
      """

    try processor.process(
      line: """
        {"version": "v0.9.1", "updateComponents": {"surfaceId": "s1", "components": \(componentsJSON)}}
        """)

    let vm = processor.getSurface(id: "s1")
    let root = vm?.rootNode
    #expect(root?.id == "root")
    if let children = root?.properties["children"] as? [Node] {
      #expect(children.count == 100)
      #expect(children.first?.id == "child0")
      #expect(children.last?.id == "child99")
    } else {
      Issue.record("Expected [Node] for children property")
    }
  }

  // MARK: - Rapid Sequential Updates

  @Test func rapidSequentialUpdatesPreserveLatestState() throws {
    let catalog = BasicCatalog.v091Catalog
    let vm = SurfaceViewModel(surfaceID: "s1", catalogs: [catalog.id: catalog])

    // Rapidly update the same data model path 500 times
    for i in 0..<500 {
      vm.dataModel.set("/counter", value: .integer(i))
    }

    let data = vm.dataModel.data
    #expect(data["counter"]?.intValue == 499)
  }

  @Test func rapidComponentUpdatesReplaceLatest() throws {
    let catalog = BasicCatalog.v091Catalog
    let processor = MessageProcessor(catalogs: [catalog.id: catalog])

    try processor.process(
      line: """
        {"version": "v0.9.1", "createSurface": {"surfaceId": "s1", "catalogId": "\(catalog.id)"}}
        """)

    for i in 0..<100 {
      try processor.process(
        line: """
          {"version": "v0.9.1", "updateComponents": {"surfaceId": "s1", "components": [
            {"id": "root", "component": "Text", "text": "Update \(i)"}
          ]}}
          """)
    }

    let vm = processor.getSurface(id: "s1")
    let root = vm?.rootNode
    #expect(root?.id == "root")
    if let binding = root?.properties["text"] as? DataBinding<String> {
      #expect(binding.value == "Update 99")
    } else {
      Issue.record("Expected DataBinding<String> for text property")
    }
  }
}
