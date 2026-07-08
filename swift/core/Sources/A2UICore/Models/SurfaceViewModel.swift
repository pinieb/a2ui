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
import OrderedCollections
import OrderedJSON

/// Manages the active component buffer, two-way data model state, and
/// active theme.
///
/// `SurfaceViewModel` is the central runtime engine that receives
/// server-to-client messages, validates component definitions, resolves
/// dynamic values (data bindings and function calls), and builds a
/// tree of ``Node`` objects ready for rendering.
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
  private var componentBuffer: [String: JSONValue] = [:]
  private var dataModel: JSONValue = .object([:])
  private var activeTheme: (any SurfaceTheme)?

  /// The root node of the resolved component tree, published to the UI
  /// on the Main Thread.
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

  /// Updates the component buffer with new component declarations after
  /// validating them.
  public func updateComponents(_ components: [[String: JSONValue]]) {
    var validUpdates: [String: JSONValue] = [:]

    for componentDict in components {
      guard let type = componentDict["component"]?.stringValue else {
        let error = ClientServerError.validationFailed(
          ValidationFailedError(
            surfaceID: surfaceID,
            path: "/component",
            message: "Missing required key 'component'"
          )
        )
        actionHandler?.handle(error: error, from: surfaceID)
        continue
      }

      guard let id = componentDict["id"]?.stringValue else {
        let error = ClientServerError.validationFailed(
          ValidationFailedError(
            surfaceID: surfaceID,
            path: "/id",
            message: "Missing required key 'id'"
          )
        )
        actionHandler?.handle(error: error, from: surfaceID)
        continue
      }

      guard let schema = catalog.schema(forType: type) else {
        let error = ClientServerError.validationFailed(
          ValidationFailedError(
            surfaceID: surfaceID,
            path: "/component",
            message: "Unknown component type '\(type)' not registered in catalog"
          )
        )
        actionHandler?.handle(error: error, from: surfaceID)
        continue
      }

      let instance: JSONValue = .object(
        OrderedDictionary(
          uniqueKeysWithValues: componentDict.map { ($0.key, $0.value) }
        )
      )
      let result = schema.validate(instance)

      if result.isValid {
        validUpdates[id] = instance
      } else {
        let errorMessage = result.errors?.first?.message ?? "Validation failed"
        let errorPath = result.errors?.first?.instanceLocation.jsonPointerString ?? "/"
        let error = ClientServerError.validationFailed(
          ValidationFailedError(
            surfaceID: surfaceID,
            path: errorPath,
            message: errorMessage
          )
        )
        actionHandler?.handle(error: error, from: surfaceID)
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
    lock.withLock { componentBuffer }
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

  // MARK: - Property Classification

  /// Classifies a schema property into an A2UI property type by
  /// inspecting its raw JSON representation.
  ///
  /// Since `swift-json-schema`'s `ObjectSchema`, `Keywords.*` types are `package`
  /// access, we inspect `Schema.jsonValue` (which returns the schema
  /// as raw `JSONValue`) to find `$ref` URIs and match them against
  /// A2UI common type names.
  private func classifySchema(_ schemaJSON: JSONValue) -> PropertyType {
    // Check for $ref to A2UI common types
    if let ref = schemaJSON["$ref"]?.stringValue {
      if ref.contains("DynamicBoolean") { return .dynamicBoolean }
      if ref.contains("DynamicString") { return .dynamicString }
      if ref.contains("DynamicNumber") { return .dynamicNumber }
      if ref.contains("DynamicValue") { return .dynamicValue }
      if ref.contains("Action") { return .action }
      if ref.contains("ChildList") { return .childList }
    }

    // Check oneOf subschemas (Dynamic* types use oneOf)
    if let oneOf = schemaJSON["oneOf"]?.arrayValue {
      for sub in oneOf {
        let type = classifySchema(sub)
        if type != .standard { return type }
      }
    }

    // Check anyOf subschemas
    if let anyOf = schemaJSON["anyOf"]?.arrayValue {
      for sub in anyOf {
        let type = classifySchema(sub)
        if type != .standard { return type }
      }
    }

    // Check allOf subschemas (Dynamic* FunctionCall variants use allOf)
    if let allOf = schemaJSON["allOf"]?.arrayValue {
      for sub in allOf {
        let type = classifySchema(sub)
        if type != .standard { return type }
      }
    }

    return .standard
  }

  // MARK: - Node Resolution

  /// Resolves a component by ID, using the component ID as both
  /// definition and instance ID.
  private func resolveNode(id: String, basePath: String? = nil) -> Node? {
    resolveNode(definitionID: id, instanceID: id, basePath: basePath)
  }

  /// Resolves a component definition into a specific instance Node.
  private func resolveNode(
    definitionID: String,
    instanceID: String,
    basePath: String?
  ) -> Node? {
    guard let componentJSON = componentBuffer[definitionID],
      let componentDict = componentJSON.dictionaryValue,
      let type = componentDict["component"]?.stringValue
    else {
      return nil
    }

    // Get the schema for this component type to classify properties
    let schema = catalog.schema(forType: type)
    let schemaJSON = schema?.jsonValue ?? .object([:])
    let propertiesSchema = schemaJSON["properties"]?.objectValue

    var resolvedProperties: [String: any Resolved] = [:]

    for (key, val) in componentDict {
      if key == "component" || key == "id" {
        continue
      }

      let propSchema = propertiesSchema?[key] ?? .boolean(true)
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
      return resolveDynamicValueBinding(value, basePath: basePath)
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

  // MARK: - Dynamic Value Evaluation

  /// Resolves a dynamic value to its current literal `JSONValue`.
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
        if let argsObj = dict["args"]?.dictionaryValue {
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

  // MARK: - Dynamic Type-Specific Resolvers

  private func resolveDynamicBoolean(
    _ value: JSONValue,
    basePath: String?
  ) -> DataBinding<Bool> {
    if let dict = value.dictionaryValue, let pathStr = dict["path"]?.stringValue {
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
    if let dict = value.dictionaryValue, let pathStr = dict["path"]?.stringValue {
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
    if let dict = value.dictionaryValue, let pathStr = dict["path"]?.stringValue {
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

  private func resolveDynamicValueBinding(
    _ value: JSONValue,
    basePath: String?
  ) -> DataBinding<JSONValue> {
    if let dict = value.dictionaryValue, let pathStr = dict["path"]?.stringValue {
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

  // MARK: - Action Resolution

  private func resolveAction(
    _ value: JSONValue,
    basePath: String?,
    componentID: String
  ) -> ResolvedAction? {
    guard let dict = value.dictionaryValue else { return nil }

    if let eventObj = dict["event"]?.dictionaryValue,
      let name = eventObj["name"]?.stringValue
    {
      let contextDict = eventObj["context"]?.dictionaryValue
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
    } else if let funcCallObj = dict["functionCall"]?.dictionaryValue,
      let call = funcCallObj["call"]?.stringValue
    {
      let argsDict = funcCallObj["args"]?.dictionaryValue
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

  // MARK: - Child List Resolution

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
        let dataItems = dataListVal.arrayValue
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
