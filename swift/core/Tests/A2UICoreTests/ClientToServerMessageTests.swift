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

struct ClientToServerMessageTests {

  // MARK: - Decoding

  @Test func decodeValidActionWithEvent() throws {
    let json = """
      {
        "version": "v0.9.1",
        "action": {
          "event": "click",
          "context": {"userId": "123"}
        }
      }
      """.data(using: .utf8)!
    let message = try JSONDecoder().decode(
      ClientToServerMessage.self, from: json
    )
    if case .action(let action) = message {
      if case .event(let name, let context) = action.identity {
        #expect(name == "click")
        #expect(context?["userId"]?.stringValue == "123")
      } else {
        Issue.record("Expected .event identity")
      }
    } else {
      Issue.record("Expected .action message")
    }
  }

  @Test func decodeValidActionWithFunctionCall() throws {
    let json = """
      {
        "version": "v0.9.1",
        "action": {
          "call": "submit",
          "args": {"formId": "contact"}
        }
      }
      """.data(using: .utf8)!
    let message = try JSONDecoder().decode(
      ClientToServerMessage.self, from: json
    )
    if case .action(let action) = message {
      if case .function(let call, let args) = action.identity {
        #expect(call == "submit")
        #expect(args?["formId"]?.stringValue == "contact")
      } else {
        Issue.record("Expected .function identity")
      }
    } else {
      Issue.record("Expected .action message")
    }
  }

  @Test func decodeValidError() throws {
    let json = """
      {
        "version": "v0.9.1",
        "error": {
          "code": "VALIDATION_FAILED",
          "surfaceId": "surface-1",
          "path": "/components/0",
          "message": "Missing required property"
        }
      }
      """.data(using: .utf8)!
    let message = try JSONDecoder().decode(
      ClientToServerMessage.self, from: json
    )
    if case .error(let error) = message {
      if case .validationFailed(let validation) = error {
        #expect(validation.surfaceID == "surface-1")
        #expect(validation.path == "/components/0")
        #expect(validation.message == "Missing required property")
      } else {
        Issue.record("Expected .validationFailed error")
      }
    } else {
      Issue.record("Expected .error message")
    }
  }

  @Test func decodeRejectsUnsupportedVersion() throws {
    let json = """
      {"version": "v2.0", "action": {"event": "click"}}
      """.data(using: .utf8)!
    #expect(throws: DecodingError.self) {
      try JSONDecoder().decode(ClientToServerMessage.self, from: json)
    }
  }

  @Test func decodeRejectsMissingActionAndError() throws {
    let json = """
      {"version": "v0.9.1"}
      """.data(using: .utf8)!
    #expect(throws: DecodingError.self) {
      try JSONDecoder().decode(ClientToServerMessage.self, from: json)
    }
  }

  @Test func decodeAcceptsVersion09() throws {
    let json = """
      {"version": "v0.9", "action": {"event": "click"}}
      """.data(using: .utf8)!
    let message = try JSONDecoder().decode(
      ClientToServerMessage.self, from: json
    )
    if case .action(let action) = message {
      if case .event(let name, _) = action.identity {
        #expect(name == "click")
      }
    }
  }

  // MARK: - Encoding

  @Test func encodeActionWithEvent() throws {
    let action = ResolvedAction(identity: .event(
      name: "click",
      context: ["userId": "123"]
    ), trigger: {})
    let message = ClientToServerMessage.action(action)
    let data = try JSONEncoder().encode(message)
    let decoded = try JSONDecoder().decode(
      ClientToServerMessage.self, from: data
    )
    #expect(decoded == message)
  }

  @Test func encodeActionWithFunctionCall() throws {
    let action = ResolvedAction(identity: .function(
      call: "submit",
      args: ["formId": "contact"]
    ), trigger: {})
    let message = ClientToServerMessage.action(action)
    let data = try JSONEncoder().encode(message)
    let decoded = try JSONDecoder().decode(
      ClientToServerMessage.self, from: data
    )
    #expect(decoded == message)
  }

  @Test func encodeValidationError() throws {
    let error = ClientServerError.validationFailed(
      ValidationFailedError(
        surfaceID: "surface-1",
        path: "/components/0",
        message: "Missing required property"
      )
    )
    let message = ClientToServerMessage.error(error)
    let data = try JSONEncoder().encode(message)
    let decoded = try JSONDecoder().decode(
      ClientToServerMessage.self, from: data
    )
    #expect(decoded == message)
  }

  @Test func encodeAlwaysUsesV091Version() throws {
    let action = ResolvedAction(
      identity: .event(name: "click", context: nil),
      trigger: {}
    )
    let message = ClientToServerMessage.action(action)
    let data = try JSONEncoder().encode(message)
    let json = try #require(String(data: data, encoding: .utf8))
    #expect(json.contains("\"version\":\"v0.9.1\""))
  }

  // MARK: - ResolvedAction Equality

  @Test func resolvedActionsEqualByIdentity() {
    let a = ResolvedAction(
      identity: .event(name: "click", context: nil),
      trigger: {}
    )
    let b = ResolvedAction(
      identity: .event(name: "click", context: nil),
      trigger: {}
    )
    #expect(a == b)
  }

  @Test func resolvedActionsNotEqualByDifferentIdentity() {
    let a = ResolvedAction(
      identity: .event(name: "click", context: nil),
      trigger: {}
    )
    let b = ResolvedAction(
      identity: .event(name: "submit", context: nil),
      trigger: {}
    )
    #expect(a != b)
  }
}
