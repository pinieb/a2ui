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

import Combine
import Foundation
import OrderedCollections
import OrderedJSON

/// The central processor for A2UI server-to-client messages.
///
/// `MessageProcessor` is a thin orchestrator that decodes incoming
/// JSONL lines, routes them to the appropriate `SurfaceViewModel`
/// via the `SurfaceGroupModel`, and throws on failure. It does not
/// own surface storage, lifecycle, or error conversion — those
/// responsibilities belong to `SurfaceGroupModel` and
/// `MessageErrorMapper` respectively.
///
/// Mirrors the `MessageProcessor` class in the `web_core`
/// reference implementation.
public final class MessageProcessor: @unchecked Sendable,
  ObservableObject
{
  /// The surface group model owning all active surfaces.
  public let group: SurfaceGroupModel

  private let catalogs: [String: any ComponentCatalog]
  private weak var actionHandler: (any ActionHandling)?
  private let parser = MessageParser()
  private let errorMapper = MessageErrorMapper()

  public init(
    catalogs: [String: any ComponentCatalog],
    actionHandler: (any ActionHandling)? = nil
  ) {
    self.catalogs = catalogs
    self.actionHandler = actionHandler
    self.group = SurfaceGroupModel()
  }

  /// Processes a single JSONL line containing an incoming message
  /// envelope.
  ///
  /// Throws on any failure (decoding error, missing surface, missing
  /// catalog). The caller is responsible for catching errors and
  /// routing them via `ActionHandling` if desired. The
  /// `MessageErrorMapper` can be used to convert thrown errors into
  /// spec-compliant `ClientServerError` values.
  public func process(line: String) throws {
    let surfaceID = parser.extractSurfaceID(fromLine: line) ?? "unknown"
    let message: ServerToClientMessage

    do {
      message = try parser.parse(jsonString: line)
    } catch {
      let clientError = errorMapper.map(error, surfaceID: surfaceID)
      actionHandler?.handle(error: clientError, from: surfaceID)
      throw error
    }

    switch message {
    case .createSurface(let createMsg):
      guard let catalog = catalogs[createMsg.catalogID] else {
        throw GenericError(
          code: "CATALOG_NOT_FOUND",
          surfaceID: createMsg.surfaceID,
          message: "Catalog not found: \(createMsg.catalogID)"
        )
      }
      let vm = SurfaceViewModel(
        surfaceID: createMsg.surfaceID,
        catalog: catalog,
        actionHandler: actionHandler
      )
      if let rawTheme = createMsg.theme {
        let themeJSON: JSONValue = .object(
          OrderedDictionary(
            uniqueKeysWithValues: rawTheme.map { ($0.key, $0.value) }
          )
        )
        if let themeObj = catalog.makeTheme(jsonObject: themeJSON) {
          vm.updateTheme(themeObj)
        }
      }
      if createMsg.shouldSendDataModel {
        group.setSendDataModel(surfaceID: createMsg.surfaceID, enabled: true)
      }
      group.addSurface(vm)

    case .updateComponents(let updateMsg):
      guard let vm = group.surface(id: updateMsg.surfaceID) else {
        throw GenericError(
          code: "SURFACE_NOT_FOUND",
          surfaceID: updateMsg.surfaceID,
          message: "Surface not found: \(updateMsg.surfaceID)"
        )
      }
      vm.updateComponents(updateMsg.components)

    case .updateDataModel(let updateMsg):
      guard let vm = group.surface(id: updateMsg.surfaceID) else {
        throw GenericError(
          code: "SURFACE_NOT_FOUND",
          surfaceID: updateMsg.surfaceID,
          message: "Surface not found: \(updateMsg.surfaceID)"
        )
      }
      vm.updateDataModel(path: updateMsg.path, value: updateMsg.value)

    case .deleteSurface(let deleteMsg):
      guard group.surface(id: deleteMsg.surfaceID) != nil else {
        throw GenericError(
          code: "SURFACE_NOT_FOUND",
          surfaceID: deleteMsg.surfaceID,
          message: "Surface not found: \(deleteMsg.surfaceID)"
        )
      }
      group.removeSurface(id: deleteMsg.surfaceID)
    }
  }

  // MARK: - Deprecated Forwarding Methods

  /// The dictionary of active surfaces, published to the UI.
  ///
  /// - Deprecated: Access via `processor.group.surfacesMap`.
  @available(*, deprecated, message: "Use group.surfacesMap")
  public var surfaces: [String: SurfaceViewModel] {
    group.surfacesMap
  }

  /// Thread-safely retrieves all active surfaces.
  ///
  /// - Deprecated: Use `group.allSurfaces()`.
  @available(*, deprecated, message: "Use group.allSurfaces()")
  public func getSurfaces() -> [String: SurfaceViewModel] {
    group.allSurfaces()
  }

  /// Thread-safely retrieves a specific surface by ID.
  ///
  /// - Deprecated: Use `group.surface(id:)`.
  @available(*, deprecated, message: "Use group.surface(id:)")
  public func getSurface(id: String) -> SurfaceViewModel? {
    group.surface(id: id)
  }
}
