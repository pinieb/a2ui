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

import Foundation

public struct SchemaProperty: Sendable {
  public let name: String
  public let type: SchemaType
  public let isRequired: Bool

  public init(name: String, type: SchemaType, isRequired: Bool = false) {
    self.name = name
    self.type = type
    self.isRequired = isRequired
  }
}

@resultBuilder
public struct SchemaBuilder {
  public static func buildBlock(
    _ components: SchemaProperty...
  ) -> [SchemaProperty] {
    components
  }
}

public struct SchemaObject: SchemaType {
  public let properties: [SchemaProperty]
  public let omitType: Bool
  public let additionalProperties: Bool

  public init(
    omitType: Bool = false,
    additionalProperties: Bool = true,
    @SchemaBuilder _ builder: () -> [SchemaProperty]
  ) {
    let props = builder()
    let names = props.map { $0.name }
    assert(
      Set(names).count == names.count,
      "Duplicate property names detected in SchemaObject: \(names)"
    )
    self.properties = props
    self.omitType = omitType
    self.additionalProperties = additionalProperties
  }

  public init(
    omitType: Bool = false,
    additionalProperties: Bool = true,
    properties: [SchemaProperty]
  ) {
    let names = properties.map { $0.name }
    assert(
      Set(names).count == names.count,
      "Duplicate property names detected in SchemaObject: \(names)"
    )
    self.properties = properties
    self.omitType = omitType
    self.additionalProperties = additionalProperties
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    if !omitType {
      try container.encode("object", forKey: .type)
    }

    var propertiesContainer = container.nestedContainer(
      keyedBy: DynamicCodingKeys.self,
      forKey: .properties
    )
    var requiredKeys: [String] = []

    for property in properties {
      try propertiesContainer.encode(
        AnyEncodable(property.type),
        forKey: DynamicCodingKeys(stringValue: property.name)
      )
      if property.isRequired {
        requiredKeys.append(property.name)
      }
    }

    if !requiredKeys.isEmpty {
      var seen = Set<String>()
      let uniqueRequired = requiredKeys.filter {
        seen.insert($0).inserted
      }.sorted()  // Sort alphabetically for perfect determinism
      try container.encode(uniqueRequired, forKey: .required)
    }

    if !additionalProperties {
      try container.encode(false, forKey: .additionalProperties)
    }
  }

  public func validate(instance: JSONValue) throws -> ValidationOutput {
    guard case .object(let dict) = instance else {
      throw ValidationError(
        path: "/",
        message: "Expected object, got \(instance.typeName)"
      )
    }

    // Reject additional properties if forbidden
    if !additionalProperties {
      let definedNames = Set(properties.map { $0.name })
      for key in dict.keys {
        if !definedNames.contains(key) {
          throw ValidationError(
            path: "/\(key)",
            message: "additional property '\(key)' is not allowed"
          )
        }
      }
    }

    var children: [String: ValidationOutput] = [:]
    for property in properties {
      if let val = dict[property.name] {
        do {
          let childOutput = try property.type.validate(instance: val)
          children[property.name] = childOutput
        } catch let error as ValidationError {
          let segment = property.name
          let prependedPath =
            error.path == "/"
            ? "/\(segment)"
            : "/\(segment)\(error.path)"
          throw ValidationError(path: prependedPath, message: error.message)
        }
      } else if property.isRequired {
        throw ValidationError(
          path: "/",
          message: "missing required property: \(property.name)"
        )
      }
    }
    return ValidationOutput(instance: instance, children: children)
  }

  private enum CodingKeys: String, CodingKey {
    case type
    case properties
    case required
    case additionalProperties
  }
}

// MARK: - Dynamic Coding Keys

struct DynamicCodingKeys: CodingKey {
  var stringValue: String
  init(stringValue: String) {
    self.stringValue = stringValue
  }
  var intValue: Int? { nil }
  init?(intValue: Int) { nil }
}
