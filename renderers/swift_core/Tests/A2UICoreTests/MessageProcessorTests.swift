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

struct MessageProcessorTests {
  @Test func `createSurface instantiates viewModel`() throws {
    let catalog = MockCatalog(schemas: [:])
    let handler = MockActionHandler()
    let processor = MessageProcessor(
      catalogs: ["cat_abc": catalog],
      actionHandler: handler
    )

    let line = """
      {
        "createSurface": {
          "surfaceId": "surf_123",
          "catalogId": "cat_abc",
          "theme": { "primaryColor": "#FFF" }
        }
      }
      """
    try processor.process(line: line)

    let vm = try #require(processor.getSurface(id: "surf_123"))
    #expect(vm.surfaceID == "surf_123")
    #expect(vm.getActiveTheme() != nil)
  }

  @Test func `updateComponents updates active viewModel`() throws {
    let catalog = MockCatalog(schemas: ["container": JSONSchema(types: [.object])])
    let handler = MockActionHandler()
    let processor = MessageProcessor(
      catalogs: ["cat_abc": catalog],
      actionHandler: handler
    )

    let createLine = """
      {
        "createSurface": {
          "surfaceId": "surf_123",
          "catalogId": "cat_abc"
        }
      }
      """
    try processor.process(line: createLine)

    let updateLine = """
      {
        "updateComponents": {
          "surfaceId": "surf_123",
          "components": [
            { "id": "root", "component": "container" }
          ]
        }
      }
      """
    try processor.process(line: updateLine)

    let vm = try #require(processor.getSurface(id: "surf_123"))
    #expect(vm.getComponents()["root"]?["component"]?.stringValue == "container")
  }

  @Test func `updateDataModel updates dataModel`() throws {
    let catalog = MockCatalog(schemas: [:])
    let handler = MockActionHandler()
    let processor = MessageProcessor(
      catalogs: ["cat_abc": catalog],
      actionHandler: handler
    )

    let createLine = """
      {
        "createSurface": {
          "surfaceId": "surf_123",
          "catalogId": "cat_abc"
        }
      }
      """
    try processor.process(line: createLine)

    let updateLine = """
      {
        "updateDataModel": {
          "surfaceId": "surf_123",
          "path": "/count",
          "value": 42
        }
      }
      """
    try processor.process(line: updateLine)

    let vm = try #require(processor.getSurface(id: "surf_123"))
    #expect(vm.getDataModel()["/count"]?.doubleValue == 42.0)
  }

  @Test func `deleteSurface clears viewModel`() throws {
    let catalog = MockCatalog(schemas: [:])
    let handler = MockActionHandler()
    let processor = MessageProcessor(
      catalogs: ["cat_abc": catalog],
      actionHandler: handler
    )

    let createLine = """
      {
        "createSurface": {
          "surfaceId": "surf_123",
          "catalogId": "cat_abc"
        }
      }
      """
    try processor.process(line: createLine)
    #expect(processor.getSurface(id: "surf_123") != nil)

    let deleteLine = """
      {
        "deleteSurface": {
          "surfaceId": "surf_123"
        }
      }
      """
    try processor.process(line: deleteLine)
    #expect(processor.getSurface(id: "surf_123") == nil)
  }

  @Test func `invalid components route ValidationError to actionHandler`() throws {
    let ageSchema = JSONSchema(types: [.integer])
    let userSchema = JSONSchema(
      types: [.object],
      properties: ["age": ageSchema]
    )
    let catalog = MockCatalog(schemas: ["user": userSchema])
    let handler = MockActionHandler()
    let processor = MessageProcessor(
      catalogs: ["cat_abc": catalog],
      actionHandler: handler
    )

    let createLine = """
      {
        "createSurface": {
          "surfaceId": "surf_123",
          "catalogId": "cat_abc"
        }
      }
      """
    try processor.process(line: createLine)

    let invalidUpdate = """
      {
        "updateComponents": {
          "surfaceId": "surf_123",
          "components": [
            {
              "id": "root",
              "component": "user",
              "age": "not_int"
            }
          ]
        }
      }
      """

    // It should not throw, but route error to handler
    try processor.process(line: invalidUpdate)

    let errors = handler.getErrors()
    #expect(errors.count == 1)
    if case .validationFailed(let error) = errors.first {
      #expect(error.code == "VALIDATION_FAILED")
      #expect(error.surfaceID == "surf_123")
      #expect(error.path == "/age")
    } else {
      Issue.record("Expected validation failed error")
    }
  }

  @Test func `decoding typeMismatch routes ValidationFailedError`() {
    let catalog = MockCatalog(schemas: [:])
    let handler = MockActionHandler()
    let processor = MessageProcessor(
      catalogs: ["cat_abc": catalog],
      actionHandler: handler
    )

    // Send surfaceId as integer instead of string
    let badLine = """
      {
        "createSurface": {
          "surfaceId": 123,
          "catalogId": "cat_abc"
        }
      }
      """
    #expect(throws: DecodingError.self) {
      try processor.process(line: badLine)
    }

    let errors = handler.getErrors()
    #expect(errors.count == 1)
    if case .validationFailed(let error) = errors.first {
      #expect(error.code == "VALIDATION_FAILED")
      #expect(error.surfaceID == "123")
      #expect(error.path == "/createSurface/surfaceId")
    } else {
      Issue.record("Expected validation failed error")
    }
  }

  @Test func `decoding dataCorrupted routes GenericError`() {
    let catalog = MockCatalog(schemas: [:])
    let handler = MockActionHandler()
    let processor = MessageProcessor(
      catalogs: ["cat_abc": catalog],
      actionHandler: handler
    )

    let badLine = """
      {invalid json}
      """
    #expect(throws: Error.self) {
      try processor.process(line: badLine)
    }

    let errors = handler.getErrors()
    #expect(errors.count == 1)
    if case .generic(let error) = errors.first {
      #expect(error.code == "PARSING_FAILED")
      #expect(error.surfaceID == "unknown")
    } else {
      Issue.record("Expected generic error")
    }
  }

  @Test func `concurrent processing does not race`() async throws {
    let catalog = MockCatalog(schemas: [:])
    let handler = MockActionHandler()
    let processor = MessageProcessor(
      catalogs: ["cat_abc": catalog],
      actionHandler: handler
    )

    let createLine = """
      {
        "createSurface": {
          "surfaceId": "surf_123",
          "catalogId": "cat_abc"
        }
      }
      """
    try processor.process(line: createLine)

    await withTaskGroup(of: Void.self) { group in
      for i in 0..<50 {
        group.addTask {
          let line = """
            {
              "updateDataModel": {
                "surfaceId": "surf_123",
                "path": "/val/k\(i)",
                "value": \(i)
              }
            }
            """
          try? processor.process(line: line)
        }
      }
    }

    let vm = try #require(processor.getSurface(id: "surf_123"))
    let model = vm.getDataModel()
    #expect(model["/val/k0"]?.doubleValue == 0.0)
    #expect(model["/val/k49"]?.doubleValue == 49.0)
  }

  @Test func `multi-surface routing works independently`() async throws {
    let catalog1 = MockCatalog(schemas: [:])
    let catalog2 = MockCatalog(schemas: [:])
    let catalogs = ["cat_1": catalog1, "cat_2": catalog2]
    let handler = MockActionHandler()
    let processor = MessageProcessor(catalogs: catalogs, actionHandler: handler)

    let create1 = """
      {
        "createSurface": {
          "surfaceId": "surf_1",
          "catalogId": "cat_1"
        }
      }
      """
    let create2 = """
      {
        "createSurface": {
          "surfaceId": "surf_2",
          "catalogId": "cat_2"
        }
      }
      """

    try processor.process(line: create1)
    try processor.process(line: create2)

    // Verify both are created
    let vm1 = try #require(processor.getSurface(id: "surf_1"))
    let vm2 = try #require(processor.getSurface(id: "surf_2"))
    #expect(vm1.surfaceID == "surf_1")
    #expect(vm2.surfaceID == "surf_2")

    // Update data model on both independently
    let update1 = """
      {
        "updateDataModel": {
          "surfaceId": "surf_1",
          "path": "/x",
          "value": 10
        }
      }
      """
    let update2 = """
      {
        "updateDataModel": {
          "surfaceId": "surf_2",
          "path": "/y",
          "value": 20
        }
      }
      """

    try processor.process(line: update1)
    try processor.process(line: update2)

    #expect(vm1.getDataModel()["/x"]?.doubleValue == 10.0)
    #expect(vm1.getDataModel()["/y"] == nil)
    #expect(vm2.getDataModel()["/y"]?.doubleValue == 20.0)
    #expect(vm2.getDataModel()["/x"] == nil)

    // Verify published surfaces dictionary
    let active = processor.getSurfaces()
    #expect(active.count == 2)
    #expect(active["surf_1"] === vm1)
    #expect(active["surf_2"] === vm2)

    // Delete one surface
    let delete1 = """
      {
        "deleteSurface": {
          "surfaceId": "surf_1"
        }
      }
      """
    try processor.process(line: delete1)

    #expect(processor.getSurface(id: "surf_1") == nil)
    #expect(processor.getSurface(id: "surf_2") !== nil)
  }

  @Test func `unknown catalog routes GenericError`() {
    let catalog = MockCatalog(schemas: [:])
    let handler = MockActionHandler()
    let processor = MessageProcessor(
      catalogs: ["cat_abc": catalog],
      actionHandler: handler
    )

    let badLine = """
      {
        "createSurface": {
          "surfaceId": "surf_123",
          "catalogId": "unknown_catalog"
        }
      }
      """
    #expect(throws: GenericError.self) {
      try processor.process(line: badLine)
    }

    let errors = handler.getErrors()
    #expect(errors.count == 1)
    if case .generic(let error) = errors.first {
      // MessageProcessor falls back to PARSING_FAILED for unhandled custom errors
      #expect(error.code == "PARSING_FAILED")
      #expect(error.surfaceID == "surf_123")
    } else {
      Issue.record("Expected PARSING_FAILED generic error")
    }
  }

  @Test func `unknown surface routes SURFACE_NOT_FOUND generic error`() {
    let catalog = MockCatalog(schemas: [:])
    let handler = MockActionHandler()
    let processor = MessageProcessor(
      catalogs: ["cat_abc": catalog],
      actionHandler: handler
    )

    // Update components on non-existent surface
    let updateComponentsLine = """
      {
        "updateComponents": {
          "surfaceId": "non_existent",
          "components": []
        }
      }
      """
    #expect(throws: GenericError.self) {
      try processor.process(line: updateComponentsLine)
    }

    // Update data model on non-existent surface
    let updateDataModelLine = """
      {
        "updateDataModel": {
          "surfaceId": "non_existent",
          "path": "/x",
          "value": 1
        }
      }
      """
    #expect(throws: GenericError.self) {
      try processor.process(line: updateDataModelLine)
    }

    // Delete non-existent surface
    let deleteSurfaceLine = """
      {
        "deleteSurface": {
          "surfaceId": "non_existent"
        }
      }
      """
    #expect(throws: GenericError.self) {
      try processor.process(line: deleteSurfaceLine)
    }

    let errors = handler.getErrors()
    #expect(errors.count == 3)
    for error in errors {
      if case .generic(let genericErr) = error {
        // MessageProcessor falls back to PARSING_FAILED for unhandled custom errors
        #expect(genericErr.code == "PARSING_FAILED")
        #expect(genericErr.surfaceID == "non_existent")
      } else {
        Issue.record("Expected PARSING_FAILED error")
      }
    }
  }

  @Test func `decoding keyNotFound routes ValidationFailedError`() {
    let catalog = MockCatalog(schemas: [:])
    let handler = MockActionHandler()
    let processor = MessageProcessor(
      catalogs: ["cat_abc": catalog],
      actionHandler: handler
    )

    // Missing required key in createSurface (e.g. catalogId is missing)
    let badLine = """
      {
        "createSurface": {
          "surfaceId": "surf_123"
        }
      }
      """
    #expect(throws: DecodingError.self) {
      try processor.process(line: badLine)
    }

    let errors = handler.getErrors()
    #expect(errors.count == 1)
    if case .validationFailed(let error) = errors.first {
      #expect(error.code == "VALIDATION_FAILED")
      #expect(error.surfaceID == "surf_123")
      #expect(error.path == "/createSurface")
    } else {
      Issue.record("Expected validation failed error for missing key")
    }
  }
}
