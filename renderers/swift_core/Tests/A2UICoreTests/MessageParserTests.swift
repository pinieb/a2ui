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

struct MessageParserTests {
  private let parser = MessageParser()

  // MARK: - Create Surface Tests

  @Test func `parsing createSurface with all fields works`() throws {
    let json = """
      {
        "createSurface": {
          "surfaceId": "surface_123",
          "catalogId": "catalog_abc",
          "theme": {
            "primaryColor": "#00BFFF",
            "fontSize": 16.0,
            "darkMode": true
          },
          "sendDataModel": true
        }
      }
      """

    let message = try parser.parse(jsonString: json)

    guard case .createSurface(let payload) = message else {
      Issue.record("Parsed message is not of type createSurface")
      return
    }

    #expect(payload.surfaceID == "surface_123")
    #expect(payload.catalogID == "catalog_abc")
    #expect(payload.shouldSendDataModel)

    let theme = try #require(payload.theme)
    #expect(theme["primaryColor"]?.stringValue == "#00BFFF")
    #expect(theme["fontSize"]?.doubleValue == 16.0)
    #expect(theme["darkMode"]?.boolValue == true)
  }

  @Test func `parsing createSurface with defaults works`() throws {
    let json = """
      {
        "createSurface": {
          "surfaceId": "surface_123",
          "catalogId": "catalog_abc"
        }
      }
      """

    let message = try parser.parse(jsonString: json)

    guard case .createSurface(let payload) = message else {
      Issue.record("Parsed message is not of type createSurface")
      return
    }

    #expect(payload.surfaceID == "surface_123")
    #expect(payload.catalogID == "catalog_abc")
    #expect(payload.theme == nil)
    #expect(!payload.shouldSendDataModel)
  }

  @Test func `parsing createSurface missing required fields throws error`() {
    let json = """
      {
        "createSurface": {
          "surfaceId": "surface_123"
        }
      }
      """
    #expect(throws: DecodingError.self) {
      try parser.parse(jsonString: json)
    }
  }

  @Test func `parsing createSurface type mismatch throws error`() {
    let json = """
      {
        "createSurface": {
          "surfaceId": 123,
          "catalogId": "catalog_abc"
        }
      }
      """
    #expect(throws: DecodingError.self) {
      try parser.parse(jsonString: json)
    }
  }

  // MARK: - Delete Surface Tests

  @Test func `parsing deleteSurface works`() throws {
    let json = """
      {
        "deleteSurface": {
          "surfaceId": "surface_456"
        }
      }
      """

    let message = try parser.parse(jsonString: json)

    guard case .deleteSurface(let payload) = message else {
      Issue.record("Parsed message is not of type deleteSurface")
      return
    }

    #expect(payload.surfaceID == "surface_456")
  }

  @Test func `parsing deleteSurface missing required fields throws error`() {
    let json = """
      {
        "deleteSurface": {}
      }
      """
    #expect(throws: DecodingError.self) {
      try parser.parse(jsonString: json)
    }
  }

  // MARK: - Update Components Tests

  @Test func `parsing updateComponents works`() throws {
    let json = """
      {
        "updateComponents": {
          "surfaceId": "surface_789",
          "components": [
            {
              "id": "comp_1",
              "type": "Text",
              "properties": {
                "text": "Hello World"
              }
            },
            {
              "id": "comp_2",
              "type": "Button",
              "properties": {
                "label": "Click Me",
                "enabled": true
              }
            }
          ]
        }
      }
      """

    let message = try parser.parse(jsonString: json)

    guard case .updateComponents(let payload) = message else {
      Issue.record("Parsed message is not of type updateComponents")
      return
    }

    #expect(payload.surfaceID == "surface_789")
    #expect(payload.components.count == 2)

    let comp1 = payload.components[0]
    #expect(comp1["id"]?.stringValue == "comp_1")
    #expect(comp1["type"]?.stringValue == "Text")
    #expect(
      comp1["properties"]?.objectValue?["text"]?.stringValue == "Hello World"
    )

    let comp2 = payload.components[1]
    #expect(comp2["id"]?.stringValue == "comp_2")
    #expect(comp2["type"]?.stringValue == "Button")
    #expect(
      comp2["properties"]?.objectValue?["label"]?.stringValue == "Click Me"
    )
    #expect(
      comp2["properties"]?.objectValue?["enabled"]?.boolValue == true
    )
  }

  @Test func `parsing updateComponents missing fields throws error`() {
    let json = """
      {
        "updateComponents": {
          "surfaceId": "surface_789"
        }
      }
      """
    #expect(throws: DecodingError.self) {
      try parser.parse(jsonString: json)
    }
  }

  // MARK: - Update Data Model Tests

  @Test func `parsing updateDataModel with all fields works`() throws {
    let json = """
      {
        "updateDataModel": {
          "surfaceId": "surface_abc",
          "path": "user/profile/name",
          "value": "Alice"
        }
      }
      """

    let message = try parser.parse(jsonString: json)

    guard case .updateDataModel(let payload) = message else {
      Issue.record("Parsed message is not of type updateDataModel")
      return
    }

    #expect(payload.surfaceID == "surface_abc")
    #expect(payload.path == "user/profile/name")
    #expect(payload.value?.stringValue == "Alice")
  }

  @Test func `parsing updateDataModel with defaults works`() throws {
    let json = """
      {
        "updateDataModel": {
          "surfaceId": "surface_abc"
        }
      }
      """

    let message = try parser.parse(jsonString: json)

    guard case .updateDataModel(let payload) = message else {
      Issue.record("Parsed message is not of type updateDataModel")
      return
    }

    #expect(payload.surfaceID == "surface_abc")
    #expect(payload.path == "/")
    #expect(payload.value == nil)
  }

  @Test func `parsing updateDataModel with null value works`() throws {
    let json = """
      {
        "updateDataModel": {
          "surfaceId": "surface_abc",
          "path": "user/profile/avatar",
          "value": null
        }
      }
      """

    let message = try parser.parse(jsonString: json)

    guard case .updateDataModel(let payload) = message else {
      Issue.record("Parsed message is not of type updateDataModel")
      return
    }

    #expect(payload.surfaceID == "surface_abc")
    #expect(payload.path == "user/profile/avatar")
    #expect(payload.value == .null)
  }

  // MARK: - Envelope Constraint and Malformed JSON Tests

  @Test func `parsing envelope with invalid key throws error`() {
    let json = """
      {
        "unknownAction": {
          "surfaceId": "surface_abc"
        }
      }
      """
    #expect(throws: DecodingError.self) {
      try parser.parse(jsonString: json)
    }
  }

  @Test func `parsing malformed JSON throws error`() {
    let json = "{ malformed json }"
    #expect(throws: DecodingError.self) {
      try parser.parse(jsonString: json)
    }
  }

  @Test func `parsing empty string throws error`() {
    #expect(throws: DecodingError.self) {
      try parser.parse(jsonString: "")
    }
  }

  @Test func `parsing invalid UTF8 string throws data corrupted error`() {
    let invalidString = String(decoding: [0xD800] as [UInt16], as: UTF16.self)
    #expect(throws: DecodingError.self) {
      try parser.parse(jsonString: invalidString)
    }
  }

  // MARK: - JSONL (JSON Lines) Streaming Tests

  @Test func `parsing JSONL stream works`() throws {
    let jsonlStream = """
      {"createSurface":{"surfaceId":"s1","catalogId":"c1"}}
      {"updateComponents":{"surfaceId":"s1","components":[]}}
      {"updateDataModel":{"surfaceId":"s1","path":"x","value":42}}
      {"deleteSurface":{"surfaceId":"s1"}}
      """

    let lines = jsonlStream.split(separator: "\n").map { String($0) }
    #expect(lines.count == 4)

    // 1. Create Surface
    let msg1 = try parser.parse(jsonString: lines[0])
    if case .createSurface(let payload) = msg1 {
      #expect(payload.surfaceID == "s1")
    } else {
      Issue.record("Expected createSurface message")
    }

    // 2. Update Components
    let msg2 = try parser.parse(jsonString: lines[1])
    if case .updateComponents(let payload) = msg2 {
      #expect(payload.surfaceID == "s1")
      #expect(payload.components.isEmpty)
    } else {
      Issue.record("Expected updateComponents message")
    }

    // 3. Update Data Model
    let msg3 = try parser.parse(jsonString: lines[2])
    if case .updateDataModel(let payload) = msg3 {
      #expect(payload.surfaceID == "s1")
      #expect(payload.path == "x")
      #expect(payload.value?.doubleValue == 42.0)
    } else {
      Issue.record("Expected updateDataModel message")
    }

    // 4. Delete Surface
    let msg4 = try parser.parse(jsonString: lines[3])
    if case .deleteSurface(let payload) = msg4 {
      #expect(payload.surfaceID == "s1")
    } else {
      Issue.record("Expected deleteSurface message")
    }
  }

  // MARK: - Round-Trip Encoding/Decoding Tests

  @Test func `createSurface message round-trip encoding and decoding works`() throws {
    let original = CreateSurfaceMessage(
      surfaceID: "surface_123",
      catalogID: "catalog_abc",
      theme: ["primaryColor": .string("#00BFFF"), "fontSize": .number(16.0)],
      shouldSendDataModel: true
    )
    let envelope = EnvelopeMessage.createSurface(original)

    let encoder = JSONEncoder()
    let data = try encoder.encode(envelope)

    let decodedEnvelope = try parser.decode(jsonData: data)

    #expect(decodedEnvelope == envelope)
  }

  @Test func `deleteSurface message round-trip encoding and decoding works`() throws {
    let original = DeleteSurfaceMessage(surfaceID: "surface_456")
    let envelope = EnvelopeMessage.deleteSurface(original)

    let encoder = JSONEncoder()
    let data = try encoder.encode(envelope)

    let decodedEnvelope = try parser.decode(jsonData: data)

    #expect(decodedEnvelope == envelope)
  }

  @Test func `updateComponents message round-trip encoding and decoding works`() throws {
    let original = UpdateComponentsMessage(
      surfaceID: "surface_789",
      components: [
        ["id": .string("comp_1"), "type": .string("Text")]
      ]
    )
    let envelope = EnvelopeMessage.updateComponents(original)

    let encoder = JSONEncoder()
    let data = try encoder.encode(envelope)

    let decodedEnvelope = try parser.decode(jsonData: data)

    #expect(decodedEnvelope == envelope)
  }

  // MARK: - Update Data Model Round-Trips

  @Test func `updateDataModel message round-trip encoding and decoding works`() throws {
    let original = UpdateDataModelMessage(
      surfaceID: "surface_abc",
      path: "user/profile/name",
      value: .string("Alice")
    )
    let envelope = EnvelopeMessage.updateDataModel(original)

    let encoder = JSONEncoder()
    let data = try encoder.encode(envelope)

    let decodedEnvelope = try parser.decode(jsonData: data)

    #expect(decodedEnvelope == envelope)
  }

  @Test func `updateDataModel message with null value round-trip works`() throws {
    let original = UpdateDataModelMessage(
      surfaceID: "surface_abc",
      path: "user/profile/avatar",
      value: .null
    )
    let envelope = EnvelopeMessage.updateDataModel(original)

    let encoder = JSONEncoder()
    let data = try encoder.encode(envelope)

    let decodedEnvelope = try parser.decode(jsonData: data)

    #expect(decodedEnvelope == envelope)
  }

  @Test func `updateDataModel message with nil value round-trip works`() throws {
    let original = UpdateDataModelMessage(
      surfaceID: "surface_abc",
      path: "user/profile/bio",
      value: nil
    )
    let envelope = EnvelopeMessage.updateDataModel(original)

    let encoder = JSONEncoder()
    let data = try encoder.encode(envelope)

    let decodedEnvelope = try parser.decode(jsonData: data)

    #expect(decodedEnvelope == envelope)
  }
}
