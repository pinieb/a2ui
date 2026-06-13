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
import JSONSchema

/// Thread-safe coordinator processing incoming JSONL streams and managing multiple
/// SurfaceViewModel lifecycles and component catalogs.
public final class MessageProcessor: @unchecked Sendable, ObservableObject {
  private let lock = NSRecursiveLock()
  private let catalogs: [String: any ComponentCatalog]
  private weak var actionHandler: (any ActionHandling)?

  private var activeSurfaces: [String: SurfaceViewModel] = [:]

  /// The dictionary of active surfaces, published to the UI on the Main Thread.
  @Published public private(set) var surfaces: [String: SurfaceViewModel] = [:]

  public init(
    catalogs: [String: any ComponentCatalog],
    actionHandler: (any ActionHandling)? = nil
  ) {
    self.catalogs = catalogs
    self.actionHandler = actionHandler
  }

  /// Processes a single JSONL line containing an incoming message envelope.
  public func process(line: String) throws {
    let parser = MessageParser()
    let surfaceID = resolveSurfaceID(fromLine: line) ?? "unknown"

    do {
      let message = try parser.parse(jsonString: line)
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
        if let rawTheme = createMsg.theme,
          let themeObj = catalog.makeTheme(jsonObject: .object(rawTheme))
        {
          vm.updateTheme(themeObj)
        }
        addSurface(vm)

      case .updateComponents(let updateMsg):
        guard let vm = getSurface(id: updateMsg.surfaceID) else {
          throw GenericError(
            code: "SURFACE_NOT_FOUND",
            surfaceID: updateMsg.surfaceID,
            message: "Surface not found: \(updateMsg.surfaceID)"
          )
        }
        vm.updateComponents(updateMsg.components)

      case .updateDataModel(let updateMsg):
        guard let vm = getSurface(id: updateMsg.surfaceID) else {
          throw GenericError(
            code: "SURFACE_NOT_FOUND",
            surfaceID: updateMsg.surfaceID,
            message: "Surface not found: \(updateMsg.surfaceID)"
          )
        }
        vm.updateDataModel(path: updateMsg.path, value: updateMsg.value)

      case .deleteSurface(let deleteMsg):
        guard getSurface(id: deleteMsg.surfaceID) != nil else {
          throw GenericError(
            code: "SURFACE_NOT_FOUND",
            surfaceID: deleteMsg.surfaceID,
            message: "Surface not found: \(deleteMsg.surfaceID)"
          )
        }
        removeSurface(id: deleteMsg.surfaceID)
      }
    } catch {
      handleError(error, surfaceID: surfaceID)
      throw error
    }
  }

  // MARK: - Thread-Safe Getters and Setters

  /// Thread-safely retrieves all active surfaces.
  public func getSurfaces() -> [String: SurfaceViewModel] {
    lock.withLock { activeSurfaces }
  }

  /// Thread-safely retrieves a specific surface by ID.
  public func getSurface(id: String) -> SurfaceViewModel? {
    lock.withLock { activeSurfaces[id] }
  }

  private func addSurface(_ vm: SurfaceViewModel) {
    lock.withLock {
      activeSurfaces[vm.surfaceID] = vm
      let currentSurfaces = activeSurfaces
      DispatchQueue.main.async { [weak self] in
        self?.surfaces = currentSurfaces
      }
    }
  }

  private func removeSurface(id: String) {
    lock.withLock {
      activeSurfaces.removeValue(forKey: id)
      let currentSurfaces = activeSurfaces
      DispatchQueue.main.async { [weak self] in
        self?.surfaces = currentSurfaces
      }
    }
  }

  // MARK: - Error Conversion & Routing

  private func handleError(_ error: Error, surfaceID: String) {
    guard let actionHandler = actionHandler else { return }

    if let validationError = error as? ValidationError {
      let validation = ValidationFailedError(
        surfaceID: surfaceID,
        path: validationError.path,
        message: validationError.message
      )
      actionHandler.handle(error: .validationFailed(validation), from: surfaceID)
    } else if let decodingError = error as? DecodingError {
      let codingPath: [CodingKey]
      switch decodingError {
      case .typeMismatch(_, let context),
        .valueNotFound(_, let context),
        .keyNotFound(_, let context),
        .dataCorrupted(let context):
        codingPath = context.codingPath
      @unknown default:
        codingPath = []
      }

      let pointer = resolveJSONPointer(from: codingPath)
      let description = resolveDecodingErrorDescription(decodingError)

      switch decodingError {
      case .typeMismatch, .valueNotFound, .keyNotFound:
        let validation = ValidationFailedError(
          surfaceID: surfaceID,
          path: pointer,
          message: description
        )
        actionHandler.handle(error: .validationFailed(validation), from: surfaceID)
      case .dataCorrupted:
        let generic = GenericError(
          code: "PARSING_FAILED",
          surfaceID: surfaceID,
          message: description
        )
        actionHandler.handle(error: .generic(generic), from: surfaceID)
      @unknown default:
        let generic = GenericError(
          code: "PARSING_FAILED",
          surfaceID: surfaceID,
          message: description
        )
        actionHandler.handle(error: .generic(generic), from: surfaceID)
      }
    } else {
      let generic = GenericError(
        code: "PARSING_FAILED",
        surfaceID: surfaceID,
        message: error.localizedDescription
      )
      actionHandler.handle(error: .generic(generic), from: surfaceID)
    }
  }

  private func resolveSurfaceID(fromLine line: String) -> String? {
    guard let data = line.data(using: .utf8),
      let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    else {
      return nil
    }

    for value in dict.values {
      if let subDict = value as? [String: Any],
        let rawID = subDict["surfaceId"]
      {
        if let strID = rawID as? String {
          return strID
        } else if let numID = rawID as? NSNumber {
          return numID.stringValue
        }
      }
    }
    return nil
  }

  private func resolveJSONPointer(from codingPath: [CodingKey]) -> String {
    guard !codingPath.isEmpty else { return "" }
    let pointer = codingPath.map { key in
      if let intVal = key.intValue {
        return String(intVal)
      } else {
        return key.stringValue
      }
    }.joined(separator: "/")
    return "/" + pointer
  }

  private func resolveDecodingErrorDescription(_ error: DecodingError) -> String {
    switch error {
    case .typeMismatch(let type, let context):
      return "Type mismatch: expected type '\(type)', got '\(context.debugDescription)'"
    case .valueNotFound(let type, let context):
      return "Missing value: expected non-nil '\(type)', got '\(context.debugDescription)'"
    case .keyNotFound(let key, let context):
      return "Missing required key '\(key.stringValue)': \(context.debugDescription)"
    case .dataCorrupted(let context):
      return "JSON syntax error: \(context.debugDescription)"
    @unknown default:
      return "Unknown decoding error"
    }
  }
}
