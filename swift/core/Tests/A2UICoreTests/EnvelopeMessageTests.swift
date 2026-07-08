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
import OrderedJSON
import Testing

struct EnvelopeMessageTests {

  // MARK: - Decoding

  @Test func decodeCreateSurface() throws {
    let json = """
      {
        "createSurface": {
          "surfaceId": "s1",
          "catalogId": "default"
        }
      }
      """.data(using: .utf8)!
    let msg = try JSONDecoder().decode(EnvelopeMessage.self, from: json)
    if case .createSurface(let create) = msg {
      #expect(create.surfaceID == "s1")
      #expect(create.catalogID == "default")
      #expect(create.shouldSendDataModel == false)
    } else {
      Issue.record("Expected .createSurface")
    }
  }

  @Test func decodeCreateSurfaceWithSendDataModel() throws {
    let json = """
      {
        "createSurface": {
          "surfaceId": "s1",
          "catalogId": "default",
          "sendDataModel": true
        }
      }
      """.data(using: .utf8)!
    let msg = try JSONDecoder().decode(EnvelopeMessage.self, from: json)
    if case .createSurface(let create) = msg {
      #expect(create.shouldSendDataModel == true)
    }
  }

  @Test func decodeUpdateComponents() throws {
    let json = """
      {
        "updateComponents": {
          "surfaceId": "s1",
          "components": [
            {"id": "btn1", "type": "button"}
          ]
        }
      }
      """.data(using: .utf8)!
    let msg = try JSONDecoder().decode(EnvelopeMessage.self, from: json)
    if case .updateComponents(let update) = msg {
      #expect(update.surfaceID == "s1")
      #expect(update.components.count == 1)
      #expect(update.components[0]["id"]?.stringValue == "btn1")
    } else {
      Issue.record("Expected .updateComponents")
    }
  }

  @Test func decodeUpdateDataModel() throws {
    let json = """
      {
        "updateDataModel": {
          "surfaceId": "s1",
          "path": "/user/name",
          "value": "Alice"
        }
      }
      """.data(using: .utf8)!
    let msg = try JSONDecoder().decode(EnvelopeMessage.self, from: json)
    if case .updateDataModel(let update) = msg {
      #expect(update.surfaceID == "s1")
      #expect(update.path == "/user/name")
      #expect(update.value?.stringValue == "Alice")
    } else {
      Issue.record("Expected .updateDataModel")
    }
  }

  @Test func decodeUpdateDataModelDefaultsToRootPath() throws {
    let json = """
      {
        "updateDataModel": {
          "surfaceId": "s1",
          "value": {"name": "Alice"}
        }
      }
      """.data(using: .utf8)!
    let msg = try JSONDecoder().decode(EnvelopeMessage.self, from: json)
    if case .updateDataModel(let update) = msg {
      #expect(update.path == "/")
    }
  }

  @Test func decodeDeleteSurface() throws {
    let json = """
      {
        "deleteSurface": {
          "surfaceId": "s1"
        }
      }
      """.data(using: .utf8)!
    let msg = try JSONDecoder().decode(EnvelopeMessage.self, from: json)
    if case .deleteSurface(let delete) = msg {
      #expect(delete.surfaceID == "s1")
    } else {
      Issue.record("Expected .deleteSurface")
    }
  }

  @Test func decodeRejectsEmptyEnvelope() throws {
    let json = "{}".data(using: .utf8)!
    #expect(throws: DecodingError.self) {
      try JSONDecoder().decode(EnvelopeMessage.self, from: json)
    }
  }

  // MARK: - Encoding Round-Trip

  @Test func encodeDecodeRoundTripCreateSurface() throws {
    let original = EnvelopeMessage.createSurface(
      CreateSurfaceMessage(
        surfaceID: "s1",
        catalogID: "default",
        theme: ["primary": "blue"],
        shouldSendDataModel: true
      )
    )
    let data = try JSONEncoder().encode(original)
    let decoded = try JSONDecoder().decode(EnvelopeMessage.self, from: data)
    #expect(decoded == original)
  }

  @Test func encodeDecodeRoundTripUpdateComponents() throws {
    let original = EnvelopeMessage.updateComponents(
      UpdateComponentsMessage(
        surfaceID: "s1",
        components: [
          ["id": "btn1", "type": "button"],
          ["id": "txt1", "type": "text"],
        ]
      )
    )
    let data = try JSONEncoder().encode(original)
    let decoded = try JSONDecoder().decode(EnvelopeMessage.self, from: data)
    #expect(decoded == original)
  }

  @Test func encodeDecodeRoundTripDeleteSurface() throws {
    let original = EnvelopeMessage.deleteSurface(
      DeleteSurfaceMessage(surfaceID: "s1")
    )
    let data = try JSONEncoder().encode(original)
    let decoded = try JSONDecoder().decode(EnvelopeMessage.self, from: data)
    #expect(decoded == original)
  }
}
