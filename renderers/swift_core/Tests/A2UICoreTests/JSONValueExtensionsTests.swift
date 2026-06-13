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

struct JSONValueExtensionsTests {

  // MARK: - String Value Tests

  @Test func `stringValue returns string when value is string`() {
    let value = JSONValue.string("hello")
    #expect(value.stringValue == "hello")
  }

  @Test func `stringValue returns nil when value is not string`() {
    let value = JSONValue.number(12.3)
    #expect(value.stringValue == nil)
  }

  // MARK: - Double Value Tests

  @Test func `doubleValue returns double when value is number`() {
    let value = JSONValue.number(45.6)
    #expect(value.doubleValue == 45.6)
  }

  @Test func `doubleValue returns nil when value is not number`() {
    let value = JSONValue.string("45.6")
    #expect(value.doubleValue == nil)
  }

  // MARK: - Bool Value Tests

  @Test func `boolValue returns bool when value is bool`() {
    let value = JSONValue.boolean(true)
    #expect(value.boolValue == true)
  }

  @Test func `boolValue returns nil when value is not bool`() {
    let value = JSONValue.null
    #expect(value.boolValue == nil)
  }

  // MARK: - Array Value Tests

  @Test func `arrayValue returns array when value is array`() {
    let value = JSONValue.array([.string("a"), .number(1.0)])
    let array = value.arrayValue
    #expect(array?.count == 2)
    #expect(array?[0].stringValue == "a")
    #expect(array?[1].doubleValue == 1.0)
  }

  @Test func `arrayValue returns nil when value is not array`() {
    let value = JSONValue.boolean(false)
    #expect(value.arrayValue == nil)
  }

  // MARK: - Object Value Tests

  @Test func `objectValue returns dictionary when value is object`() {
    let value = JSONValue.object(["key": .number(100.0)])
    let object = value.objectValue
    #expect(object?.count == 1)
    #expect(object?["key"]?.doubleValue == 100.0)
  }

  @Test func `objectValue returns nil when value is not object`() {
    let value = JSONValue.array([])
    #expect(value.objectValue == nil)
  }
}
