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

struct NodeTests {

  @Test func `simple node equality compares id and type`() {
    let node1 = Node(id: "btn1", type: "button", properties: [:])
    let node2 = Node(id: "btn1", type: "button", properties: [:])
    let node3 = Node(id: "btn2", type: "button", properties: [:])
    let node4 = Node(id: "btn1", type: "text", properties: [:])

    #expect(node1 == node2)
    #expect(node1 != node3)
    #expect(node1 != node4)
  }

  @Test func `node properties equality compares primitive resolved types`() {
    let props1: [String: any Resolved] = [
      "label": "Click me",
      "size": 12,
      "ratio": 1.5,
      "enabled": true,
    ]
    let props2: [String: any Resolved] = [
      "label": "Click me",
      "size": 12,
      "ratio": 1.5,
      "enabled": true,
    ]
    let props3: [String: any Resolved] = [
      "label": "Different",
      "size": 12,
      "ratio": 1.5,
      "enabled": true,
    ]
    let props4: [String: any Resolved] = [
      "label": "Click me",
      "size": 12,
      "ratio": 1.5,
      "enabled": true,
      "extra": "extra",
    ]
    let props5: [String: any Resolved] = [
      "label": "Click me",
      "size": 12,
      "ratio": 1.5,
      "different": true,
    ]

    let node1 = Node(id: "btn1", type: "button", properties: props1)
    let node2 = Node(id: "btn1", type: "button", properties: props2)
    let node3 = Node(id: "btn1", type: "button", properties: props3)
    let node4 = Node(id: "btn1", type: "button", properties: props4)
    let node5 = Node(id: "btn1", type: "button", properties: props5)

    #expect(node1 == node2)
    #expect(node1 != node3)
    #expect(node1 != node4)
    #expect(node1 != node5)
  }

  @Test func `node properties equality compares JSONValues`() {
    let json1 = JSONValue.object(["a": .string("foo"), "b": .number(2.0)])
    let json2 = JSONValue.object(["a": .string("foo"), "b": .number(2.0)])
    let json3 = JSONValue.object(["a": .string("foo"), "b": .number(3.0)])

    let node1 = Node(id: "1", type: "card", properties: ["config": json1])
    let node2 = Node(id: "1", type: "card", properties: ["config": json2])
    let node3 = Node(id: "1", type: "card", properties: ["config": json3])

    #expect(node1 == node2)
    #expect(node1 != node3)
  }

  @Test func `nested child arrays equality compares deep tree structures`() {
    let child1 = Node(id: "c1", type: "text", properties: ["text": "A"])
    let child2 = Node(id: "c2", type: "text", properties: ["text": "B"])

    let parent1 = Node(
      id: "p", type: "stack",
      properties: [
        "children": [child1, child2] as [Node]
      ])
    let parent2 = Node(
      id: "p", type: "stack",
      properties: [
        "children": [child1, child2] as [Node]
      ])
    let parent3 = Node(
      id: "p", type: "stack",
      properties: [
        "children": [child1] as [Node]
      ])
    let parent4 = Node(
      id: "p", type: "stack",
      properties: [
        "children": [child2, child1] as [Node]
      ])

    #expect(parent1 == parent2)
    #expect(parent1 != parent3)
    #expect(parent1 != parent4)

    #expect(parent1.children.count == 2)
    #expect(parent1.children[0].id == "c1")
  }

  @Test func `single nested node in properties is compared correctly`() {
    let headerNode1 = Node(id: "h1", type: "header", properties: ["title": "Welcome"])
    let headerNode2 = Node(id: "h1", type: "header", properties: ["title": "Welcome"])
    let headerNode3 = Node(id: "h1", type: "header", properties: ["title": "Goodbye"])

    let parent1 = Node(
      id: "p1", type: "screen",
      properties: [
        "header": headerNode1
      ])
    let parent2 = Node(
      id: "p1", type: "screen",
      properties: [
        "header": headerNode2
      ])
    let parent3 = Node(
      id: "p1", type: "screen",
      properties: [
        "header": headerNode3
      ])

    #expect(parent1 == parent2)
    #expect(parent1 != parent3)
  }

  @Test func `node equality handles DataBinding and ResolvedAction identities`() {
    let binding1 = DataBinding<String>(
      identity: .path("name"), get: { "" }, set: { _ in })
    let binding2 = DataBinding<String>(
      identity: .path("name"), get: { "x" }, set: { _ in })
    let binding3 = DataBinding<String>(
      identity: .path("email"), get: { "" }, set: { _ in })

    let action1 = ResolvedAction(
      identity: .event(name: "ok", context: nil), trigger: {})
    let action2 = ResolvedAction(
      identity: .event(name: "ok", context: nil), trigger: {})
    let action3 = ResolvedAction(
      identity: .event(name: "cancel", context: nil), trigger: {})

    let node1 = Node(
      id: "form", type: "form",
      properties: [
        "value": binding1,
        "submit": action1,
      ])
    let node2 = Node(
      id: "form", type: "form",
      properties: [
        "value": binding2,  // Same identity, different closures
        "submit": action2,  // Same identity, different closures
      ])
    let node3 = Node(
      id: "form", type: "form",
      properties: [
        "value": binding3,  // Different identity
        "submit": action1,
      ])
    let node4 = Node(
      id: "form", type: "form",
      properties: [
        "value": binding1,
        "submit": action3,  // Different identity
      ])

    #expect(node1 == node2)
    #expect(node1 != node3)
    #expect(node1 != node4)
  }

  @Test func `ComponentProperties holds JSON and is Equatable`() {
    let schema = JSONSchema(types: [.string])
    let props1 = ComponentProperties(
      type: "text", schema: schema, json: .string("hello"))
    let props2 = ComponentProperties(
      type: "text", schema: schema, json: .string("hello"))
    let props3 = ComponentProperties(
      type: "text", schema: schema, json: .string("world"))

    #expect(props1.type == "text")
    #expect(props1.schema == schema)
    #expect(props1.json == .string("hello"))
    #expect(props1 == props2)
    #expect(props1 != props3)
  }
}
