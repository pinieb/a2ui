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

/// A thread-safe tracker to record resolved nodes in the spy catalog.
private final class SpyTracker: @unchecked Sendable {
  static let shared = SpyTracker()
  private let lock = NSLock()
  private var _resolvedNodes: [Node] = []

  var resolvedNodes: [Node] {
    lock.withLock { _resolvedNodes }
  }

  func record(_ node: Node) {
    lock.withLock { _resolvedNodes.append(node) }
  }

  func clear() {
    lock.withLock { _resolvedNodes.removeAll() }
  }
}

/// A Spy Catalog to verify node resolution during rendering.
private struct SpyCatalog: CatalogView {
  let node: Node

  init(node: Node) {
    self.node = node
    SpyTracker.shared.record(node)
  }

  var body: some View {
    Text(node.id)
      .accessibilityIdentifier(node.id)
  }
}

@MainActor struct SurfaceRenderingTests {

  private func unwrapView(_ view: Any) -> Any {
    var current = view
    while true {
      let mirror = Mirror(reflecting: current)
      if String(describing: type(of: current)).hasPrefix("_ConditionalContent"),
        let storage = mirror.descendant("storage")
      {
        let storageMirror = Mirror(reflecting: storage)
        if let activeContent = storageMirror.children.first?.value {
          current = activeContent
          continue
        }
      }
      if String(describing: type(of: current)).hasPrefix("ModifiedContent"),
        let content = mirror.descendant("content")
      {
        current = content
        continue
      }
      break
    }
    return current
  }

  // MARK: - Tier 1: Feature Coverage

  @Test func `Surface renders loading progress view when root node is nil`() {
    SpyTracker.shared.clear()
    let vm = SurfaceViewModel(
      surfaceID: "surf_nil",
      catalog: MockComponentCatalog(schemas: [:])
    )
    let surface = Surface(viewModel: vm, catalogType: SpyCatalog.self)

    let body = surface.body
    let unwrapped = unwrapView(body)
    #expect(unwrapped is ProgressView<EmptyView, EmptyView>)
    #expect(SpyTracker.shared.resolvedNodes.isEmpty)
  }

  @Test func `Surface renders resolved root node successfully`() async throws {
    SpyTracker.shared.clear()
    let textSchema = JSONSchema(types: [.object])
    let vm = SurfaceViewModel(
      surfaceID: "surf_1",
      catalog: MockComponentCatalog(schemas: ["Text": textSchema])
    )

    let components: [[String: JSONValue]] = [
      [
        "id": .string("root"),
        "component": .string("Text"),
      ]
    ]

    vm.updateComponents(components)

    // Wait for the async update to rootNode
    for _ in 0..<10 {
      if vm.rootNode != nil { break }
      try await Task.sleep(nanoseconds: 10_000_000)
    }

    let surface = Surface(viewModel: vm, catalogType: SpyCatalog.self)
    let body = surface.body

    let unwrapped = unwrapView(body)
    #expect(unwrapped is SpyCatalog)

    let spyCatalog = unwrapped as! SpyCatalog
    #expect(spyCatalog.node.id == "root")
    #expect(spyCatalog.node.type == "Text")
  }

  // MARK: - Tier 2: Boundary & Corner Cases

  @Test func `Tree builder resolves deeply nested tree layout without stack overflow`() async throws
  {
    let commonURL = URL(string: "https://a2ui.org/schemas/v0_9_1/common.json")!
    JSONSchema.dynamicRegistry[commonURL] = JSONSchema(
      id: "https://a2ui.org/schemas/v0_9_1/common.json",
      defs: [
        "ChildList": JSONSchema(types: [.object, .array])
      ]
    )

    let containerSchema = JSONSchema(
      types: [.object],
      properties: [
        "children": JSONSchema(
          ref: "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/ChildList"
        )
      ]
    )

    let vm = SurfaceViewModel(
      surfaceID: "surf_deep",
      catalog: MockComponentCatalog(schemas: ["Container": containerSchema])
    )

    // Build a deeply nested tree (50 levels deep)
    var components: [[String: JSONValue]] = []
    for i in 0..<50 {
      let id = i == 0 ? "root" : "node_\(i)"
      let childId = i == 49 ? nil : "node_\(i+1)"
      var properties: [String: JSONValue] = [
        "id": .string(id),
        "component": .string("Container"),
      ]
      if let child = childId {
        properties["children"] = .array([.string(child)])
      }
      components.append(properties)
    }

    vm.updateComponents(components)

    for _ in 0..<10 {
      if vm.rootNode != nil { break }
      try await Task.sleep(nanoseconds: 10_000_000)
    }

    let root = vm.rootNode
    #expect(root != nil)

    // Traverse the tree to verify it built successfully without stack overflow
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

    #expect(depth == 50)
  }

  @Test func `Surface instances with identical root nodes are equal`() {
    let componentCatalog = MockComponentCatalog()
    let vm1 = SurfaceViewModel(surfaceID: "surf_1", catalog: componentCatalog)
    let vm2 = SurfaceViewModel(surfaceID: "surf_2", catalog: componentCatalog)

    let surface1 = Surface(viewModel: vm1, catalogType: MockCatalog.self)
    let surface1Duplicate = Surface(viewModel: vm1, catalogType: MockCatalog.self)
    let surface2 = Surface(viewModel: vm2, catalogType: MockCatalog.self)

    #expect(surface1 == surface1Duplicate)
    #expect(surface1 != surface2)
  }

  @Test func `Surface can be rendered inside a Hosting Controller`() async throws {
    let textSchema = JSONSchema(types: [.object])
    let componentCatalog = MockComponentCatalog(schemas: ["Text": textSchema])
    let vm = SurfaceViewModel(surfaceID: "surf_hosting", catalog: componentCatalog)
    let components: [[String: JSONValue]] = [
      [
        "id": .string("root"),
        "component": .string("Text"),
        "text": .string("Hello Hosting"),
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

    #expect(vm.rootNode != nil)
  }
}
