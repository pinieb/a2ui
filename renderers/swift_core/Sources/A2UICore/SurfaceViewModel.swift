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

/// Manages the active component buffer, two-way data model state, and active theme.
public final class SurfaceViewModel: @unchecked Sendable, ObservableObject {

  // MARK: - Types

  private enum PropertyType {
    case dynamicBoolean
    case dynamicString
    case dynamicNumber
    case dynamicValue
    case action
    case childList
    case standard
  }

  // MARK: - Properties

  private let lock = NSRecursiveLock()

  public let surfaceID: String
  public let catalog: any ComponentCatalog
  public weak var actionHandler: (any ActionHandling)?

  // Protected State
  private var componentBuffer: [String: ValidationOutput] = [:]
  private var dataModel: JSONValue = .object([:])
  private var activeTheme: (any SurfaceTheme)?

  /// The root node of the resolved component tree, published to the UI on the Main Thread.
  @Published public private(set) var rootNode: Node?

  // MARK: - Initialization

  public init(
    surfaceID: String,
    catalog: any ComponentCatalog,
    actionHandler: (any ActionHandling)? = nil
  ) {
    self.surfaceID = surfaceID
    self.catalog = catalog
    self.actionHandler = actionHandler
  }

  // MARK: - Public API

  /// Updates the component buffer with new component declarations after validating them.
  public func updateComponents(_ components: [[String: JSONValue]]) {
    var validUpdates: [String: ValidationOutput] = [:]

    for componentDict in components {
      guard let type = componentDict["component"]?.stringValue else {
        let error = ClientServerError.validationFailed(
          ValidationFailedError(
            surfaceID: self.surfaceID,
            path: "/component",
            message: "Missing required key 'component'"
          )
        )
        self.actionHandler?.handle(error: error, from: self.surfaceID)
        continue
      }

      guard let id = componentDict["id"]?.stringValue else {
        let error = ClientServerError.validationFailed(
          ValidationFailedError(
            surfaceID: self.surfaceID,
            path: "/id",
            message: "Missing required key 'id'"
          )
        )
        self.actionHandler?.handle(error: error, from: self.surfaceID)
        continue
      }

      guard let schema = catalog.schema(forType: type) else {
        let error = ClientServerError.validationFailed(
          ValidationFailedError(
            surfaceID: self.surfaceID,
            path: "/component",
            message: "Unknown component type '\(type)' not registered in catalog"
          )
        )
        self.actionHandler?.handle(error: error, from: self.surfaceID)
        continue
      }

      var isValid = true
      var validationOutput: ValidationOutput?

      do {
        validationOutput = try schema.validate(instance: .object(componentDict))
      } catch let validationError as ValidationError {
        let error = ClientServerError.validationFailed(
          ValidationFailedError(
            surfaceID: self.surfaceID,
            path: validationError.path,
            message: validationError.message
          )
        )
        self.actionHandler?.handle(error: error, from: self.surfaceID)
        isValid = false
      } catch {
        let error = ClientServerError.generic(
          GenericError(
            code: "VALIDATION_FAILED",
            surfaceID: self.surfaceID,
            message: error.localizedDescription
          )
        )
        self.actionHandler?.handle(error: error, from: self.surfaceID)
        isValid = false
      }

      if isValid, let validationOutput {
        validUpdates[id] = validationOutput
      }
    }

    if !validUpdates.isEmpty {
      lock.withLock {
        for (id, val) in validUpdates {
          componentBuffer[id] = val
        }
        rebuildTree()
      }
    }
  }

  /// Updates a specific path in the two-way data model.
  public func updateDataModel(path: String, value: JSONValue?) {
    lock.withLock {
      dataModel[path] = value
      rebuildTree()
    }
  }

  /// Updates the active surface theme.
  public func updateTheme(_ theme: any SurfaceTheme) {
    lock.withLock {
      activeTheme = theme
      rebuildTree()
    }
  }

  /// Retrieves a thread-safe copy of the component buffer.
  public func getComponents() -> [String: JSONValue] {
    lock.withLock {
      componentBuffer.mapValues { $0.instance }
    }
  }

  /// Retrieves a thread-safe copy of the data model.
  public func getDataModel() -> JSONValue {
    lock.withLock { dataModel }
  }

  /// Retrieves a thread-safe copy of the active theme.
  public func getActiveTheme() -> (any SurfaceTheme)? {
    lock.withLock { activeTheme }
  }

  // MARK: - Tree Rebuilding

  /// Rebuilds the node tree and publishes the new root.
  private func rebuildTree() {
    let newRoot = resolveNode(id: "root")

    // Hopping to Main Thread to update the @Published property safely
    DispatchQueue.main.async { [weak self] in
      self?.rootNode = newRoot
    }
  }

  // MARK: - Property Resolution

  /// Classifies a schema into an A2UI property type.
  private func classifySchema(_ schema: JSONSchema) -> PropertyType {
    if let ref = schema.ref {
      if ref.contains("DynamicBoolean") { return .dynamicBoolean }
      if ref.contains("DynamicString") { return .dynamicString }
      if ref.contains("DynamicNumber") { return .dynamicNumber }
      if ref.contains("DynamicValue") { return .dynamicValue }
      if ref.contains("Action") { return .action }
      if ref.contains("ChildList") { return .childList }
    }
    if let local = schema.localSchema?.value {
      let type = classifySchema(local)
      if type != .standard { return type }
    }
    if let oneOf = schema.oneOf {
      for sub in oneOf {
        let type = classifySchema(sub)
        if type != .standard { return type }
      }
    }
    if let anyOf = schema.anyOf {
      for sub in anyOf {
        let type = classifySchema(sub)
        if type != .standard { return type }
      }
    }
    if let allOf = schema.allOf {
      for sub in allOf {
        let type = classifySchema(sub)
        if type != .standard { return type }
      }
    }
    return .standard
  }

  /// Resolves a component by ID, using the component ID as both definition and instance ID.
  private func resolveNode(id: String, basePath: String? = nil) -> Node? {
    resolveNode(definitionID: id, instanceID: id, basePath: basePath)
  }

  /// Resolves a component definition into a specific instance Node.
  private func resolveNode(
    definitionID: String,
    instanceID: String,
    basePath: String?
  ) -> Node? {
    guard let validationOutput = componentBuffer[definitionID],
      case .object(let componentDict) = validationOutput.instance,
      let type = componentDict["component"]?.stringValue
    else {
      return nil
    }

    var resolvedProperties: [String: any Resolved] = [:]

    for (key, val) in componentDict {
      if key == "component" || key == "id" {
        continue
      }

      let propSchema =
        validationOutput.children[key]?.schema
        ?? JSONSchema(booleanSchema: true)
      let propType = classifySchema(propSchema)

      if let resolvedVal = resolveProperty(
        value: val,
        type: propType,
        basePath: basePath,
        componentID: instanceID,
        propertyKey: key
      ) {
        resolvedProperties[key] = resolvedVal
      }
    }

    return Node(id: instanceID, type: type, properties: resolvedProperties)
  }

  private func resolveProperty(
    value: JSONValue,
    type: PropertyType,
    basePath: String?,
    componentID: String,
    propertyKey: String
  ) -> (any Resolved)? {
    switch type {
    case .dynamicBoolean:
      return resolveDynamicBoolean(value, basePath: basePath)
    case .dynamicString:
      return resolveDynamicString(value, basePath: basePath)
    case .dynamicNumber:
      return resolveDynamicNumber(value, basePath: basePath)
    case .dynamicValue:
      return resolveDynamicValue(value, basePath: basePath)
    case .action:
      return resolveAction(value, basePath: basePath, componentID: componentID)
    case .childList:
      return resolveChildList(
        value,
        basePath: basePath,
        componentID: componentID,
        propertyKey: propertyKey
      )
    case .standard:
      return value
    }
  }

  /// Resolves a dynamic value to its current literal JSONValue.
  private func evaluateDynamicValue(
    _ value: JSONValue,
    basePath: String?
  ) -> JSONValue {
    switch value {
    case .object(let dict):
      if let pathStr = dict["path"]?.stringValue {
        let absPath = JSONValue.absolutePath(for: pathStr, in: basePath)
        return dataModel[absPath] ?? .null
      } else if let callName = dict["call"]?.stringValue {
        guard let function = catalog.localFunction(for: callName) else {
          return .null
        }
        var resolvedArgs: [String: JSONValue] = [:]
        if let argsObj = dict["args"]?.objectValue {
          for (argKey, argVal) in argsObj {
            resolvedArgs[argKey] = evaluateDynamicValue(argVal, basePath: basePath)
          }
        }
        do {
          return try function.evaluate(arguments: resolvedArgs)
        } catch {
          return .null
        }
      }
      return value
    default:
      return value
    }
  }

  private func resolveDynamicBoolean(
    _ value: JSONValue,
    basePath: String?
  ) -> DataBinding<Bool> {
    if case .object(let dict) = value, let pathStr = dict["path"]?.stringValue {
      let absPath = JSONValue.absolutePath(for: pathStr, in: basePath)
      return DataBinding<Bool>(
        identity: .path(absPath),
        get: { [weak self] in
          guard let self else { return false }
          return self.lock.withLock {
            self.dataModel[absPath]?.boolValue ?? false
          }
        },
        set: { [weak self] newValue in
          guard let self else { return }
          self.lock.withLock {
            self.dataModel[absPath] = .boolean(newValue)
            self.rebuildTree()
          }
        }
      )
    }
    return DataBinding<Bool>(
      identity: .literal(value),
      get: { [weak self] in
        guard let self else { return value.boolValue ?? false }
        return self.lock.withLock {
          self.evaluateDynamicValue(value, basePath: basePath).boolValue ?? false
        }
      },
      set: { _ in }
    )
  }

  private func resolveDynamicString(
    _ value: JSONValue,
    basePath: String?
  ) -> DataBinding<String> {
    if case .object(let dict) = value, let pathStr = dict["path"]?.stringValue {
      let absPath = JSONValue.absolutePath(for: pathStr, in: basePath)
      return DataBinding<String>(
        identity: .path(absPath),
        get: { [weak self] in
          guard let self else { return "" }
          return self.lock.withLock {
            self.dataModel[absPath]?.stringValue ?? ""
          }
        },
        set: { [weak self] newValue in
          guard let self else { return }
          self.lock.withLock {
            self.dataModel[absPath] = .string(newValue)
            self.rebuildTree()
          }
        }
      )
    }
    return DataBinding<String>(
      identity: .literal(value),
      get: { [weak self] in
        guard let self else { return value.stringValue ?? "" }
        return self.lock.withLock {
          self.evaluateDynamicValue(value, basePath: basePath).stringValue ?? ""
        }
      },
      set: { _ in }
    )
  }

  private func resolveDynamicNumber(
    _ value: JSONValue,
    basePath: String?
  ) -> DataBinding<Double> {
    if case .object(let dict) = value, let pathStr = dict["path"]?.stringValue {
      let absPath = JSONValue.absolutePath(for: pathStr, in: basePath)
      return DataBinding<Double>(
        identity: .path(absPath),
        get: { [weak self] in
          guard let self else { return 0.0 }
          return self.lock.withLock {
            self.dataModel[absPath]?.doubleValue ?? 0.0
          }
        },
        set: { [weak self] newValue in
          guard let self else { return }
          self.lock.withLock {
            self.dataModel[absPath] = .number(newValue)
            self.rebuildTree()
          }
        }
      )
    }
    return DataBinding<Double>(
      identity: .literal(value),
      get: { [weak self] in
        guard let self else { return value.doubleValue ?? 0.0 }
        return self.lock.withLock {
          self.evaluateDynamicValue(value, basePath: basePath).doubleValue ?? 0.0
        }
      },
      set: { _ in }
    )
  }

  private func resolveDynamicValue(
    _ value: JSONValue,
    basePath: String?
  ) -> DataBinding<JSONValue> {
    if case .object(let dict) = value, let pathStr = dict["path"]?.stringValue {
      let absPath = JSONValue.absolutePath(for: pathStr, in: basePath)
      return DataBinding<JSONValue>(
        identity: .path(absPath),
        get: { [weak self] in
          guard let self else { return .null }
          return self.lock.withLock {
            self.dataModel[absPath] ?? .null
          }
        },
        set: { [weak self] newValue in
          guard let self else { return }
          self.lock.withLock {
            self.dataModel[absPath] = newValue
            self.rebuildTree()
          }
        }
      )
    }
    return DataBinding<JSONValue>(
      identity: .literal(value),
      get: { [weak self] in
        guard let self else { return value }
        return self.lock.withLock {
          self.evaluateDynamicValue(value, basePath: basePath)
        }
      },
      set: { _ in }
    )
  }

  private func resolveAction(
    _ value: JSONValue,
    basePath: String?,
    componentID: String
  ) -> ResolvedAction? {
    guard case .object(let dict) = value else { return nil }

    if let eventObj = dict["event"]?.objectValue,
      let name = eventObj["name"]?.stringValue
    {
      let contextDict = eventObj["context"]?.objectValue
      let unresolvedIdentity = ResolvedAction.Identity.event(
        name: name,
        context: contextDict
      )

      return ResolvedAction(
        identity: unresolvedIdentity,
        trigger: { [weak self] in
          guard let self else { return }
          var resolvedContext: [String: JSONValue] = [:]
          if let contextDict {
            self.lock.withLock {
              for (key, val) in contextDict {
                resolvedContext[key] = self.evaluateDynamicValue(
                  val,
                  basePath: basePath
                )
              }
            }
          }

          let triggerAction = ResolvedAction(
            identity: .event(name: name, context: resolvedContext),
            trigger: {}
          )

          self.actionHandler?.handle(action: triggerAction, from: self.surfaceID)
        }
      )
    } else if let funcCallObj = dict["functionCall"]?.objectValue,
      let call = funcCallObj["call"]?.stringValue
    {
      let argsDict = funcCallObj["args"]?.objectValue
      let unresolvedIdentity = ResolvedAction.Identity.function(
        call: call,
        args: argsDict
      )

      return ResolvedAction(
        identity: unresolvedIdentity,
        trigger: { [weak self] in
          guard let self else { return }
          var resolvedArgs: [String: JSONValue] = [:]
          if let argsDict {
            self.lock.withLock {
              for (key, val) in argsDict {
                resolvedArgs[key] = self.evaluateDynamicValue(
                  val,
                  basePath: basePath
                )
              }
            }
          }

          let triggerAction = ResolvedAction(
            identity: .function(call: call, args: resolvedArgs),
            trigger: {}
          )

          self.actionHandler?.handle(action: triggerAction, from: self.surfaceID)
        }
      )
    }

    return nil
  }

  private func resolveChildList(
    _ value: JSONValue,
    basePath: String?,
    componentID: String,
    propertyKey: String
  ) -> [Node]? {
    switch value {
    case .array(let arr):
      var resolvedNodes: [Node] = []
      for item in arr {
        guard let childID = item.stringValue else { continue }
        if let childNode = resolveNode(id: childID, basePath: basePath) {
          resolvedNodes.append(childNode)
        }
      }
      return resolvedNodes

    case .object(let dict):
      guard
        let templateID =
          (dict["componentId"]?.stringValue
            ?? dict["template"]?.stringValue),
        let pathStr = (dict["path"]?.stringValue ?? dict["data"]?.stringValue)
      else {
        return nil
      }

      let absPath = JSONValue.absolutePath(for: pathStr, in: basePath)

      guard let dataListVal = dataModel[absPath],
        case .array(let dataItems) = dataListVal
      else {
        return []
      }

      var expandedNodes: [Node] = []

      for (index, _) in dataItems.enumerated() {
        let itemID = "\(templateID)_\(index)"
        let itemBasePath = "\(absPath)/\(index)"

        if let childNode = resolveNode(
          definitionID: templateID,
          instanceID: itemID,
          basePath: itemBasePath
        ) {
          expandedNodes.append(childNode)
        }
      }

      return expandedNodes

    default:
      return nil
    }
  }
}
