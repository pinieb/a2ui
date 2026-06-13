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

struct ClientToServerMessageTests {
  private let encoder = JSONEncoder()
  private let decoder = JSONDecoder()

  @Test func testClientToServerMessageActionRoundTrip() throws {
    let action = ResolvedAction(
      identity: .event(name: "submit", context: ["value": .string("hello")]),
      trigger: {}
    )
    let msg = ClientToServerMessage.action(action)
    let data = try encoder.encode(msg)
    let decoded = try decoder.decode(ClientToServerMessage.self, from: data)
    #expect(decoded == msg)
  }

  @Test func testClientToServerMessageFunctionRoundTrip() throws {
    let action = ResolvedAction(
      identity: .function(call: "validate", args: ["input": .number(42)]),
      trigger: {}
    )
    let msg = ClientToServerMessage.action(action)
    let data = try encoder.encode(msg)
    let decoded = try decoder.decode(ClientToServerMessage.self, from: data)
    #expect(decoded == msg)
  }

  @Test func testClientToServerMessageErrorValidationFailedRoundTrip() throws {
    let valError = ValidationFailedError(
      surfaceID: "s123",
      path: "/profile/age",
      message: "Value must be positive"
    )
    let clientError = ClientServerError.validationFailed(valError)
    let msg = ClientToServerMessage.error(clientError)
    let data = try encoder.encode(msg)
    let decoded = try decoder.decode(ClientToServerMessage.self, from: data)
    #expect(decoded == msg)
  }

  @Test func testClientToServerMessageErrorGenericRoundTrip() throws {
    let genError = GenericError(
      code: "INTERNAL_ERROR",
      surfaceID: "s123",
      message: "Something went wrong"
    )
    let clientError = ClientServerError.generic(genError)
    let msg = ClientToServerMessage.error(clientError)
    let data = try encoder.encode(msg)
    let decoded = try decoder.decode(ClientToServerMessage.self, from: data)
    #expect(decoded == msg)
  }

  @Test func testClientToServerMessageUnsupportedVersion() {
    let json = """
      {
        "version": "v0.8",
        "action": {
          "event": "submit"
        }
      }
      """
    let data = json.data(using: .utf8)!
    #expect(throws: DecodingError.self) {
      try decoder.decode(ClientToServerMessage.self, from: data)
    }
  }

  @Test func testClientToServerMessageMissingActionAndError() {
    let json = """
      {
        "version": "v0.9.1"
      }
      """
    let data = json.data(using: .utf8)!
    #expect(throws: DecodingError.self) {
      try decoder.decode(ClientToServerMessage.self, from: data)
    }
  }

  @Test func testClientToServerMessageBothActionAndError() {
    let json = """
      {
        "version": "v0.9.1",
        "action": {
          "event": "submit"
        },
        "error": {
          "code": "GENERIC",
          "surfaceId": "s1",
          "message": "err"
        }
      }
      """
    let data = json.data(using: .utf8)!
    let decoded = try? decoder.decode(ClientToServerMessage.self, from: data)
    guard case .action(let action) = decoded else {
      Issue.record("Expected to decode action when both action and error are present")
      return
    }
    #expect(action.identity == .event(name: "submit", context: nil))
  }

  @Test func testClientServerErrorUnknownStructure() {
    let json = """
      {
        "code": "SOME_UNKNOWN_CODE",
        "surfaceId": "s1"
      }
      """
    let data = json.data(using: .utf8)!
    #expect(throws: DecodingError.self) {
      try decoder.decode(ClientServerError.self, from: data)
    }
  }

  @Test func testValidationFailedErrorInvalidCode() {
    let json = """
      {
        "code": "NOT_VALIDATION_FAILED",
        "surfaceId": "s1",
        "path": "/x",
        "message": "msg"
      }
      """
    let data = json.data(using: .utf8)!
    #expect(throws: DecodingError.self) {
      try decoder.decode(ValidationFailedError.self, from: data)
    }
  }

}
