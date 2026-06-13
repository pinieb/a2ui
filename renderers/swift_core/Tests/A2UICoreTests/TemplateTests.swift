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

struct TemplateTests {
  @Test func `static child lists`() async throws {
    let childListSchema = JSONSchema(ref: "common_types.json#/$defs/ChildList")
    let parentSchema = JSONSchema(
      types: [.object],
      properties: ["children": childListSchema]
    )
    let childSchema = JSONSchema(types: [.object])

    let catalog = MockCatalog(schemas: [
      "Parent": parentSchema,
      "Child": childSchema,
    ])
    let vm = SurfaceViewModel(surfaceID: "surf_1", catalog: catalog)

    let components: [[String: JSONValue]] = [
      [
        "id": .string("root"),
        "component": .string("Parent"),
        "children": .array([.string("child1"), .string("child2")]),
      ],
      [
        "id": .string("child1"),
        "component": .string("Child"),
      ],
      [
        "id": .string("child2"),
        "component": .string("Child"),
      ],
    ]

    vm.updateComponents(components)

    for _ in 0..<10 {
      if vm.rootNode != nil { break }
      try await Task.sleep(nanoseconds: 10_000_000)
    }

    guard let root = vm.rootNode else {
      Issue.record("Failed to resolve root")
      return
    }

    #expect(root.type == "Parent")
    #expect(root.children.count == 2)
    #expect(root.children[0].id == "child1")
    #expect(root.children[1].id == "child2")
  }

  @Test func `dynamic template expansion with localized path scope`() async throws {
    let childListSchema = JSONSchema(ref: "common_types.json#/$defs/ChildList")
    let stringSchema = JSONSchema(ref: "common_types.json#/$defs/DynamicString")

    let parentSchema = JSONSchema(
      types: [.object],
      properties: ["items": childListSchema]
    )
    let cardSchema = JSONSchema(
      types: [.object],
      properties: [
        "title": stringSchema,
        "appTitle": stringSchema,
      ]
    )

    let catalog = MockCatalog(schemas: [
      "Parent": parentSchema,
      "Card": cardSchema,
    ])
    let vm = SurfaceViewModel(surfaceID: "surf_1", catalog: catalog)

    let components: [[String: JSONValue]] = [
      [
        "id": .string("root"),
        "component": .string("Parent"),
        "items": .object([
          "componentId": .string("Card"),
          "path": .string("/feed/cards"),
        ]),
      ],
      [
        "id": .string("Card"),
        "component": .string("Card"),
        "title": .object(["path": .string("title")]),  // relative path
        "appTitle": .object(["path": .string("/app/name")]),  // absolute path
      ],
    ]

    // Set initial data model
    vm.updateDataModel(path: "/app/name", value: .string("A2UI Demo"))
    vm.updateDataModel(
      path: "/feed/cards",
      value: .array([
        .object(["title": .string("Card One")]),
        .object(["title": .string("Card Two")]),
        .object(["title": .string("Card Three")]),
      ])
    )

    vm.updateComponents(components)

    for _ in 0..<10 {
      if vm.rootNode != nil { break }
      try await Task.sleep(nanoseconds: 10_000_000)
    }

    guard let root = vm.rootNode else {
      Issue.record("Failed to resolve root")
      return
    }

    guard let items = root.properties["items"] as? [Node] else {
      Issue.record("Failed to resolve items property to Node array")
      return
    }

    #expect(items.count == 3)

    // Verify first item
    let firstItem = items[0]
    #expect(firstItem.id == "Card_0")
    #expect(firstItem.type == "Card")
    guard let title0 = firstItem.properties["title"] as? DataBinding<String>,
      let appTitle0 = firstItem.properties["appTitle"] as? DataBinding<String>
    else {
      Issue.record("Failed to resolve Card_0 properties")
      return
    }
    #expect(title0.get() == "Card One")
    #expect(appTitle0.get() == "A2UI Demo")

    // Verify second item
    let secondItem = items[1]
    #expect(secondItem.id == "Card_1")
    guard let title1 = secondItem.properties["title"] as? DataBinding<String>,
      let appTitle1 = secondItem.properties["appTitle"] as? DataBinding<String>
    else {
      Issue.record("Failed to resolve Card_1 properties")
      return
    }
    #expect(title1.get() == "Card Two")
    #expect(appTitle1.get() == "A2UI Demo")

    // Verify third item
    let thirdItem = items[2]
    #expect(thirdItem.id == "Card_2")
    guard let title2 = thirdItem.properties["title"] as? DataBinding<String>,
      let appTitle2 = thirdItem.properties["appTitle"] as? DataBinding<String>
    else {
      Issue.record("Failed to resolve Card_2 properties")
      return
    }
    #expect(title2.get() == "Card Three")
    #expect(appTitle2.get() == "A2UI Demo")
  }
}
