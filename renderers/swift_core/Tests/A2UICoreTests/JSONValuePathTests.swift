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
import JSONSchema
import Testing

struct JSONValuePathTests {
  @Test func `get path from object works`() {
    let json: JSONValue = .object([
      "user": .object([
        "name": .string("Alice"),
        "age": .number(30),
      ])
    ])

    #expect(json["/user/name"] == .string("Alice"))
    #expect(json["/user/age"] == .number(30))
    #expect(json["/user/missing"] == nil)
    #expect(json["/missing/path"] == nil)
  }

  @Test func `get path from array works`() {
    let json: JSONValue = .object([
      "items": .array([
        .string("first"),
        .object(["price": .number(10.5)]),
      ])
    ])

    #expect(json["/items/0"] == .string("first"))
    #expect(json["/items/1/price"] == .number(10.5))
    #expect(json["/items/2"] == nil)
    #expect(json["/items/invalid_index"] == nil)
  }

  @Test func `set path in object works`() {
    var json: JSONValue = .object([:])
    json["/user/name"] = .string("Bob")
    #expect(json["/user/name"] == .string("Bob"))

    json["/user/age"] = .number(25)
    #expect(json["/user/age"] == .number(25))

    json["/user/name"] = nil
    #expect(json["/user/name"] == nil)
    #expect(json["/user/age"] == .number(25))
  }

  @Test func `set path in array works`() {
    var json: JSONValue = .object([
      "items": .array([])
    ])

    json["/items/0"] = .string("apple")
    #expect(json["/items/0"] == .string("apple"))

    json["/items/1"] = .string("banana")
    #expect(json["/items/1"] == .string("banana"))

    json["/items/0"] = .string("apricot")
    #expect(json["/items/0"] == .string("apricot"))

    json["/items/0"] = nil
    #expect(json["/items/0"] == .string("banana"))
  }

  @Test func `set nested path on empty node creates objects and arrays`() {
    var json: JSONValue = .null
    json["/user/name"] = .string("Charlie")
    #expect(json["/user/name"] == .string("Charlie"))

    var arrayJson: JSONValue = .null
    arrayJson["/0/item"] = .string("first")
    #expect(arrayJson["/0/item"] == .string("first"))
  }

  @Test func `deleting elements in nested arrays works`() {
    var json: JSONValue = .object([
      "users": .array([
        .object([
          "roles": .array([.string("admin"), .string("user")])
        ])
      ])
    ])

    // Delete "user" role
    json["/users/0/roles/1"] = nil
    #expect(json["/users/0/roles/0"] == .string("admin"))
    #expect(json["/users/0/roles/1"] == nil)

    // Delete "admin" role
    json["/users/0/roles/0"] = nil
    guard case .array(let roles) = json["/users/0/roles"] else {
      Issue.record("Expected roles to be an array")
      return
    }
    #expect(roles.isEmpty)
  }

  @Test func `appending elements at array count vs modifying existing indices`() {
    var json: JSONValue = .object([
      "items": .array([.string("apple")])
    ])

    // Modifying existing index 0
    json["/items/0"] = .string("apricot")
    #expect(json["/items/0"] == .string("apricot"))

    // Appending at array.count (1)
    json["/items/1"] = .string("banana")
    #expect(json["/items/0"] == .string("apricot"))
    #expect(json["/items/1"] == .string("banana"))
  }

  @Test func `setting values at indices out of bounds`() {
    var json: JSONValue = .object([
      "items": .array([.string("apple")])
    ])

    // Setting value at index 2 (out of bounds, since count is 1)
    json["/items/2"] = .string("cherry")
    // Should be ignored, count remains 1
    #expect(json["/items/0"] == .string("apple"))
    #expect(json["/items/1"] == nil)
    #expect(json["/items/2"] == nil)

    // Nested out-of-bounds setting
    json["/items/2/name"] = .string("cherry")
    #expect(json["/items/0"] == .string("apple"))
    #expect(json["/items/2"] == nil)
  }

  @Test func `setting values at non integer keys on array node coerces to object`() {
    var json: JSONValue = .array([.string("apple")])

    json["/key"] = .string("banana")
    #expect(json == .object(["key": .string("banana")]))

    var json2: JSONValue = .array([.string("apple")])
    json2["/key/nested"] = .string("banana")
    #expect(json2 == .object(["key": .object(["nested": .string("banana")])]))
  }

  @Test func `setting values on primitive node`() {
    var json: JSONValue = .string("hello")

    // Non-integer key creates object
    json["/key"] = .string("value")
    #expect(json == .object(["key": .string("value")]))

    var json2: JSONValue = .string("hello")
    // Integer key 0 creates array
    json2["/0"] = .string("value")
    #expect(json2 == .array([.string("value")]))

    var json3: JSONValue = .string("hello")
    // Nil value is ignored
    json3["/key"] = nil
    #expect(json3 == .string("hello"))
  }

  @Test func `absolute path resolution works`() {
    #expect(JSONValue.absolutePath(for: "name", in: "/user") == "/user/name")
    #expect(JSONValue.absolutePath(for: "/absolute", in: "/user") == "/absolute")
    #expect(JSONValue.absolutePath(for: "name", in: nil) == "/name")
    #expect(JSONValue.absolutePath(for: "name", in: "") == "/name")
    #expect(JSONValue.absolutePath(for: "name", in: "/user/") == "/user/name")
  }
}
