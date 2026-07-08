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
import A2UIJSON
import Foundation
import JSONSchema
import OrderedJSON
import Testing

/// A catalog with a simple text component schema for testing.
struct TestProcessorCatalog: ComponentCatalog {
  let textSchema: Schema

  init() throws {
    textSchema = try Schema(
      instance: """
        {
          "type": "object",
          "properties": {
            "id": { "type": "string" },
            "component": { "type": "string" },
            "text": { "$ref": "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/DynamicString" }
          },
          "required": ["id", "component"]
        }
        """,
      remoteSchemas: A2UICommonSchema.allSchemas
    )
  }

  func schema(forType type: String) -> Schema? {
    switch type {
    case "text": return textSchema
    default: return nil
    }
  }

  func makeTheme(jsonObject: JSONValue) -> (any SurfaceTheme)? {
    nil
  }

  func localFunction(for name: String) -> (any LocalFunction)? {
    nil
  }
}

/// A test action handler that captures actions and errors.
final class TestProcessorActionHandler: ActionHandling, @unchecked Sendable {
  var capturedActions: [ResolvedAction] = []
  var capturedErrors: [ClientServerError] = []

  func handle(action: ResolvedAction, from surfaceID: String) {
    capturedActions.append(action)
  }

  func handle(error: ClientServerError, from surfaceID: String) {
    capturedErrors.append(error)
  }
}

struct MessageParserTests {

  @Test func parseValidCreateSurface() throws {
    let parser = MessageParser()
    let json = """
      {"createSurface": {"surfaceId": "s1", "catalogId": "default"}}
      """
    let msg = try parser.parse(jsonString: json)
    if case .createSurface(let create) = msg {
      #expect(create.surfaceID == "s1")
      #expect(create.catalogID == "default")
    } else {
      Issue.record("Expected .createSurface")
    }
  }

  @Test func parseValidUpdateComponents() throws {
    let parser = MessageParser()
    let json = """
      {"updateComponents": {"surfaceId": "s1", "components": []}}
      """
    let msg = try parser.parse(jsonString: json)
    if case .updateComponents(let update) = msg {
      #expect(update.surfaceID == "s1")
    } else {
      Issue.record("Expected .updateComponents")
    }
  }

  @Test func parseInvalidJsonThrows() throws {
    let parser = MessageParser()
    #expect(throws: DecodingError.self) {
      try parser.parse(jsonString: "not valid json")
    }
  }

  @Test func parseEmptyObjectThrows() throws {
    let parser = MessageParser()
    #expect(throws: DecodingError.self) {
      try parser.parse(jsonString: "{}")
    }
  }

  @Test func decodeFromData() throws {
    let parser = MessageParser()
    let json = """
      {"deleteSurface": {"surfaceId": "s1"}}
      """.data(using: .utf8)!
    let msg = try parser.decode(jsonData: json)
    if case .deleteSurface(let delete) = msg {
      #expect(delete.surfaceID == "s1")
    } else {
      Issue.record("Expected .deleteSurface")
    }
  }
}

struct MessageProcessorTests {

  // MARK: - Setup

  private func makeProcessor() throws -> (MessageProcessor, TestProcessorActionHandler) {
    let handler = TestProcessorActionHandler()
    let catalog = try TestProcessorCatalog()
    let processor = MessageProcessor(
      catalogs: ["default": catalog],
      actionHandler: handler
    )
    return (processor, handler)
  }

  // MARK: - Create Surface

  @Test func processCreateSurfaceCreatesSurface() throws {
    let (processor, _) = try makeProcessor()
    try processor.process(line: """
      {"createSurface": {"surfaceId": "s1", "catalogId": "default"}}
      """)
    #expect(processor.getSurface(id: "s1") != nil)
  }

  @Test func processCreateSurfaceWithUnknownCatalogThrows() throws {
    let (processor, handler) = try makeProcessor()
    #expect(throws: GenericError.self) {
      try processor.process(line: """
        {"createSurface": {"surfaceId": "s1", "catalogId": "unknown"}}
        """)
    }
    #expect(handler.capturedErrors.count == 1)
  }

  @Test func processCreateSurfaceWithTheme() throws {
    let (processor, _) = try makeProcessor()
    try processor.process(line: """
      {"createSurface": {"surfaceId": "s1", "catalogId": "default", "theme": {"color": "blue"}}}
      """)
    #expect(processor.getSurface(id: "s1") != nil)
  }

  // MARK: - Update Components

  @Test func processUpdateComponents() throws {
    let (processor, _) = try makeProcessor()
    try processor.process(line: """
      {"createSurface": {"surfaceId": "s1", "catalogId": "default"}}
      """)
    try processor.process(line: """
      {"updateComponents": {"surfaceId": "s1", "components": [
        {"id": "root", "component": "text", "text": "Hello"}
      ]}}
      """)
    let vm = processor.getSurface(id: "s1")
    let components = vm?.getComponents()
    #expect(components?["root"] != nil)
  }

  @Test func processUpdateComponentsForMissingSurfaceThrows() throws {
    let (processor, handler) = try makeProcessor()
    #expect(throws: GenericError.self) {
      try processor.process(line: """
        {"updateComponents": {"surfaceId": "missing", "components": []}}
        """)
    }
    #expect(handler.capturedErrors.count == 1)
  }

  // MARK: - Update Data Model

  @Test func processUpdateDataModel() throws {
    let (processor, _) = try makeProcessor()
    try processor.process(line: """
      {"createSurface": {"surfaceId": "s1", "catalogId": "default"}}
      """)
    try processor.process(line: """
      {"updateDataModel": {"surfaceId": "s1", "path": "/user/name", "value": "Alice"}}
      """)
    let vm = processor.getSurface(id: "s1")
    let data = vm?.getDataModel()
    #expect(data?["user/name"]?.stringValue == "Alice")
  }

  // MARK: - Delete Surface

  @Test func processDeleteSurface() throws {
    let (processor, _) = try makeProcessor()
    try processor.process(line: """
      {"createSurface": {"surfaceId": "s1", "catalogId": "default"}}
      """)
    try processor.process(line: """
      {"deleteSurface": {"surfaceId": "s1"}}
      """)
    #expect(processor.getSurface(id: "s1") == nil)
  }

  @Test func processDeleteSurfaceForMissingSurfaceThrows() throws {
    let (processor, handler) = try makeProcessor()
    #expect(throws: GenericError.self) {
      try processor.process(line: """
        {"deleteSurface": {"surfaceId": "missing"}}
        """)
    }
    #expect(handler.capturedErrors.count == 1)
  }

  // MARK: - Error Handling

  @Test func processInvalidJsonRoutesError() throws {
    let (processor, handler) = try makeProcessor()
    #expect(throws: DecodingError.self) {
      try processor.process(line: "not valid json")
    }
    #expect(handler.capturedErrors.count == 1)
  }

  // MARK: - Surface Management

  @Test func getSurfacesReturnsAllActiveSurfaces() throws {
    let (processor, _) = try makeProcessor()
    try processor.process(line: """
      {"createSurface": {"surfaceId": "s1", "catalogId": "default"}}
      """)
    try processor.process(line: """
      {"createSurface": {"surfaceId": "s2", "catalogId": "default"}}
      """)
    let surfaces = processor.getSurfaces()
    #expect(surfaces.count == 2)
    #expect(surfaces["s1"] != nil)
    #expect(surfaces["s2"] != nil)
  }

  @Test func getSurfaceReturnsNilForUnknownID() throws {
    let (processor, _) = try makeProcessor()
    #expect(processor.getSurface(id: "unknown") == nil)
  }

  // MARK: - shouldSendDataModel

  @Test func processCreateSurfaceWithSendDataModelSendsAction() throws {
    let (processor, handler) = try makeProcessor()
    try processor.process(line: """
      {"createSurface": {"surfaceId": "s1", "catalogId": "default", "sendDataModel": true}}
      """)
    #expect(handler.capturedActions.count == 1)
    if case .event(let name, _) = handler.capturedActions[0].identity {
      #expect(name == "sendDataModel")
    }
  }

  @Test func processCreateSurfaceWithoutSendDataModelDoesNotSendAction() throws {
    let (processor, handler) = try makeProcessor()
    try processor.process(line: """
      {"createSurface": {"surfaceId": "s1", "catalogId": "default"}}
      """)
    #expect(handler.capturedActions.isEmpty)
  }
}
