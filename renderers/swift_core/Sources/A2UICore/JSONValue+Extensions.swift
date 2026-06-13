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

import JSONSchema

extension JSONValue {
  /// Returns the underlying string value if this is a `.string` case.
  public var stringValue: String? {
    switch self {
    case .string(let value): return value
    default: return nil
    }
  }

  /// Returns the underlying double value if this is a `.number` case.
  public var doubleValue: Double? {
    switch self {
    case .number(let value): return value
    default: return nil
    }
  }

  /// Returns the underlying boolean value if this is a `.boolean` case.
  public var boolValue: Bool? {
    switch self {
    case .boolean(let value): return value
    default: return nil
    }
  }

  /// Returns the underlying array of JSONValues if this is an `.array` case.
  public var arrayValue: [JSONValue]? {
    switch self {
    case .array(let value): return value
    default: return nil
    }
  }

  /// Returns the underlying dictionary of JSONValues if this is an `.object` case.
  public var objectValue: [String: JSONValue]? {
    switch self {
    case .object(let value): return value
    default: return nil
    }
  }

  /// Thread-safe getter and setter for deep path-based subscripting.
  public subscript(path: String) -> JSONValue? {
    get {
      let components = parsePath(path)
      if components.isEmpty { return self }
      var currentValue = self
      for component in components {
        switch currentValue {
        case .object(let dictionary):
          guard let value = dictionary[component] else { return nil }
          currentValue = value
        case .array(let array):
          guard let index = Int(component),
            index >= 0 && index < array.count
          else { return nil }
          currentValue = array[index]
        default:
          return nil
        }
      }
      return currentValue
    }
    set {
      let components = parsePath(path)
      guard !components.isEmpty else {
        if let newValue, case .object = newValue {
          self = newValue
        }
        return
      }
      if let updated = update(
        node: self,
        components: components[...],
        newValue: newValue
      ) {
        self = updated
      } else {
        self = .null
      }
    }
  }

  private func parsePath(_ path: String) -> [String] {
    path.split(separator: "/").map { String($0) }
  }

  private func update(
    node: JSONValue?,
    components: ArraySlice<String>,
    newValue: JSONValue?
  ) -> JSONValue? {
    guard let key = components.first else { return newValue }
    let isLastComponent = components.count == 1
    let remainingComponents = components.dropFirst()

    switch node {
    case .some(.object(var dict)):
      if isLastComponent {
        dict[key] = newValue
      } else {
        let nextNode = dict[key]
        dict[key] = update(
          node: nextNode,
          components: remainingComponents,
          newValue: newValue
        )
      }
      return .object(dict)

    case .some(.array(var array)):
      if let index = Int(key), index >= 0 {
        if index <= array.count {
          if isLastComponent {
            if let newValue {
              if index == array.count {
                array.append(newValue)
              } else {
                array[index] = newValue
              }
            } else if index < array.count {
              array.remove(at: index)
            }
          } else {
            let nextNode = index < array.count ? array[index] : nil
            let updated = update(
              node: nextNode,
              components: remainingComponents,
              newValue: newValue
            )
            if let updated {
              if index == array.count {
                array.append(updated)
              } else {
                array[index] = updated
              }
            } else if index < array.count {
              array.remove(at: index)
            }
          }
        }
        return .array(array)
      } else {
        if newValue == nil && isLastComponent { return node }
        var dict: [String: JSONValue] = [:]
        if isLastComponent {
          dict[key] = newValue
        } else {
          dict[key] = update(
            node: nil,
            components: remainingComponents,
            newValue: newValue
          )
        }
        return .object(dict)
      }

    default:
      if newValue == nil { return node }
      if let index = Int(key), index == 0 {
        var array: [JSONValue] = []
        if isLastComponent {
          if let newValue { array.append(newValue) }
        } else if let updated = update(
          node: nil,
          components: remainingComponents,
          newValue: newValue
        ) {
          array.append(updated)
        }
        return .array(array)
      } else {
        var dict: [String: JSONValue] = [:]
        if isLastComponent {
          dict[key] = newValue
        } else {
          dict[key] = update(
            node: nil,
            components: remainingComponents,
            newValue: newValue
          )
        }
        return .object(dict)
      }
    }
  }

  /// Resolves a relative or absolute path against a base path context.
  public static func absolutePath(
    for path: String,
    in basePath: String?
  ) -> String {
    if path.hasPrefix("/") { return path }
    let base = basePath ?? ""
    let trimmedBase = base.hasSuffix("/") ? String(base.dropLast()) : base
    if trimmedBase.isEmpty { return "/\(path)" }
    return "\(trimmedBase)/\(path)"
  }
}
