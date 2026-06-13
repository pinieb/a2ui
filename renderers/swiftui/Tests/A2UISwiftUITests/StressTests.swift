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

@MainActor struct StressTests {

  // MARK: - Stress Test 1: Deep Nesting Layout Performance

  @Test func `Deeply nested tree layout renders successfully in SwiftUI hosting controller`()
    async throws
  {
    let commonURL = URL(string: "https://a2ui.org/schemas/v0_9_1/common.json")!
    JSONSchema.dynamicRegistry[commonURL] = JSONSchema(
      id: "https://a2ui.org/schemas/v0_9_1/common.json",
      defs: [
        "ChildList": JSONSchema(types: [.object, .array])
      ]
    )

    let vstackSchema = JSONSchema(
      types: [.object],
      properties: [
        "children": JSONSchema(
          ref: "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/ChildList"
        )
      ]
    )

    let catalog = MockComponentCatalog(schemas: ["VStack": vstackSchema])
    let vm = SurfaceViewModel(surfaceID: "surf_deep_render", catalog: catalog)

    // Build a deeply nested tree (100 levels deep)
    var components: [[String: JSONValue]] = []
    for i in 0..<100 {
      let id = i == 0 ? "root" : "node_\(i)"
      let childId = i == 99 ? nil : "node_\(i+1)"
      var properties: [String: JSONValue] = [
        "id": .string(id),
        "component": .string("VStack"),
      ]
      if let child = childId {
        properties["children"] = .array([.string(child)])
      }
      components.append(properties)
    }

    vm.updateComponents(components)

    for _ in 0..<20 {
      if vm.rootNode != nil { break }
      try await Task.sleep(nanoseconds: 10_000_000)
    }

    let root = vm.rootNode
    #expect(root != nil)

    let surface = Surface(viewModel: vm, catalogType: MockCatalog.self)

    #if os(macOS)
      let hostingController = NSHostingController(rootView: surface)
      let window = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: 200, height: 200),
        styleMask: [.borderless],
        backing: .buffered,
        defer: false
      )
      window.contentView = hostingController.view
      window.layoutIfNeeded()
    #else
      let hostingController = UIHostingController(rootView: surface)
      let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 200, height: 200))
      window.rootViewController = hostingController
      window.makeKeyAndVisible()
      hostingController.view.layoutIfNeeded()
    #endif

    // Verify that the hierarchy can be fully traversed without issues
    var current = root
    var depth = 0
    while current != nil {
      depth += 1
      if let children = current?.properties["children"] as? [Node], !children.isEmpty {
        current = children.first
      } else {
        current = nil
      }
    }
    #expect(depth == 100)
  }

  // MARK: - Stress Test 2: Concurrency & Lock Contention

  @Test func `Rapid concurrent data model updates and rendering layout passes do not race`()
    async throws
  {
    let textSchema = JSONSchema(types: [.object])
    let catalog = MockComponentCatalog(schemas: ["Text": textSchema])
    let vm = SurfaceViewModel(surfaceID: "surf_concurrent", catalog: catalog)

    vm.updateDataModel(path: "/text_val", value: .string("Initial"))

    let components: [[String: JSONValue]] = [
      [
        "id": .string("root"),
        "component": .string("Text"),
        "text": .object([
          "type": .string("path"),
          "path": .string("/text_val"),
        ]),
      ]
    ]
    vm.updateComponents(components)

    for _ in 0..<10 {
      if vm.rootNode != nil { break }
      try await Task.sleep(nanoseconds: 10_000_000)
    }

    let surface = Surface(viewModel: vm, catalogType: MockCatalog.self)

    #if os(macOS)
      let hostingController = NSHostingController(rootView: surface)
      let window = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: 100, height: 100),
        styleMask: [.borderless],
        backing: .buffered,
        defer: false
      )
      window.contentView = hostingController.view
      window.layoutIfNeeded()
    #else
      let hostingController = UIHostingController(rootView: surface)
      let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
      window.rootViewController = hostingController
      window.makeKeyAndVisible()
      hostingController.view.layoutIfNeeded()
    #endif

    let iterations = 200
    let concurrentTasks = 10

    await withTaskGroup(of: Void.self) { group in
      for t in 0..<concurrentTasks {
        group.addTask {
          for i in 0..<iterations {
            let newVal = "Val-\(t)-\(i)"
            vm.updateDataModel(path: "/text_val", value: .string(newVal))
            await Task.yield()
          }
        }
      }

      // Simultaneously perform layout passes on the Main Actor thread
      for _ in 0..<iterations {
        #if os(macOS)
          window.layoutIfNeeded()
        #else
          hostingController.view.layoutIfNeeded()
        #endif
        try? await Task.sleep(nanoseconds: 1_000_000)
      }
    }

    #if os(macOS)
      window.layoutIfNeeded()
    #else
      hostingController.view.layoutIfNeeded()
    #endif

    let finalVal = vm.getDataModel()["/text_val"]?.stringValue
    #expect(finalVal != nil)
    #expect(finalVal!.hasPrefix("Val-"))
  }

  // MARK: - Stress Test 3: Missing Optional Properties Resilience

  @Test func `Missing optional properties on components fall back to safe defaults gracefully`()
    async throws
  {
    let commonURL = URL(string: "https://a2ui.org/schemas/v0_9_1/common.json")!
    JSONSchema.dynamicRegistry[commonURL] = JSONSchema(
      id: "https://a2ui.org/schemas/v0_9_1/common.json",
      defs: [
        "ChildList": JSONSchema(types: [.object, .array])
      ]
    )

    let vstackSchema = JSONSchema(
      types: [.object],
      properties: [
        "children": JSONSchema(
          ref: "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/ChildList"
        )
      ]
    )

    let textSchema = JSONSchema(types: [.object])
    let buttonSchema = JSONSchema(types: [.object])

    let catalog = MockComponentCatalog(schemas: [
      "VStack": vstackSchema,
      "Text": textSchema,
      "Button": buttonSchema,
    ])

    let vm = SurfaceViewModel(surfaceID: "surf_missing_optional", catalog: catalog)

    let components: [[String: JSONValue]] = [
      [
        "id": .string("root"),
        "component": .string("VStack"),
        "children": .array([
          .string("text_missing"),
          .string("btn_missing"),
        ]),
      ],
      [
        "id": .string("text_missing"),
        "component": .string("Text"),
      ],
      [
        "id": .string("btn_missing"),
        "component": .string("Button"),
      ],
    ]

    vm.updateComponents(components)

    for _ in 0..<10 {
      if vm.rootNode != nil { break }
      try await Task.sleep(nanoseconds: 10_000_000)
    }

    let root = vm.rootNode
    #expect(root != nil)

    let surface = Surface(viewModel: vm, catalogType: MockCatalog.self)

    #if os(macOS)
      let hostingController = NSHostingController(rootView: surface)
      let window = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: 200, height: 200),
        styleMask: [.borderless],
        backing: .buffered,
        defer: false
      )
      window.contentView = hostingController.view
      window.layoutIfNeeded()
    #else
      let hostingController = UIHostingController(rootView: surface)
      let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 200, height: 200))
      window.rootViewController = hostingController
      window.makeKeyAndVisible()
      hostingController.view.layoutIfNeeded()
    #endif

    // Verify that the tree built with all children successfully
    let children = root?.properties["children"] as? [Node]
    #expect(children != nil)
    #expect(children!.count == 2)
  }
}
