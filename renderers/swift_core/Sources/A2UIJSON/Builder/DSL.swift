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
  public let additionalProperties: SchemaType?
  public let patternProperties: [SchemaPatternProperty]?
  private let propertyNames: Set<String>
  private let propertiesByName: [String: SchemaProperty]

  public init(
    omitType: Bool = false,
    additionalProperties: Bool = true,
    patternProperties: [SchemaPatternProperty]? = nil,
    @SchemaBuilder _ builder: () -> [SchemaProperty]
  ) {
    let props = builder()
    let names = props.map { $0.name }
    let nameSet = Set(names)
    assert(
      nameSet.count == names.count,
      "Duplicate property names detected in SchemaObject: \(names)"
    )
    self.properties = props
    self.omitType = omitType
    self.additionalProperties = additionalProperties ? nil : SchemaNone()
    self.patternProperties = patternProperties
    self.propertyNames = nameSet
    var propMap: [String: SchemaProperty] = [:]
    for prop in props {
      propMap[prop.name] = prop
    }
    self.propertiesByName = propMap
  }

  public init(
    omitType: Bool = false,
    additionalProperties: Bool = true,
    patternProperties: [SchemaPatternProperty]? = nil,
    properties: [SchemaProperty]
  ) {
    let names = properties.map { $0.name }
    let nameSet = Set(names)
    assert(
      nameSet.count == names.count,
      "Duplicate property names detected in SchemaObject: \(names)"
    )
    self.properties = properties
    self.omitType = omitType
    self.additionalProperties = additionalProperties ? nil : SchemaNone()
    self.patternProperties = patternProperties
    self.propertyNames = nameSet
    var propMap: [String: SchemaProperty] = [:]
    for prop in properties {
      propMap[prop.name] = prop
    }
    self.propertiesByName = propMap
  }

  public init(
    omitType: Bool = false,
    additionalProperties: SchemaType?,
    patternProperties: [SchemaPatternProperty]? = nil,
    @SchemaBuilder _ builder: () -> [SchemaProperty]
  ) {
    let props = builder()
    let names = props.map { $0.name }
    let nameSet = Set(names)
    assert(
      nameSet.count == names.count,
      "Duplicate property names detected in SchemaObject: \(names)"
    )
    self.properties = props
    self.omitType = omitType
    self.additionalProperties = additionalProperties
    self.patternProperties = patternProperties
    self.propertyNames = nameSet
    var propMap: [String: SchemaProperty] = [:]
    for prop in props {
      propMap[prop.name] = prop
    }
    self.propertiesByName = propMap
  }

  public init(
    omitType: Bool = false,
    additionalProperties: SchemaType?,
    patternProperties: [SchemaPatternProperty]? = nil,
    properties: [SchemaProperty]
  ) {
    let names = properties.map { $0.name }
    let nameSet = Set(names)
    assert(
      nameSet.count == names.count,
      "Duplicate property names detected in SchemaObject: \(names)"
    )
    self.properties = properties
    self.omitType = omitType
    self.additionalProperties = additionalProperties
    self.patternProperties = patternProperties
    self.propertyNames = nameSet
    var propMap: [String: SchemaProperty] = [:]
    for prop in properties {
      propMap[prop.name] = prop
    }
    self.propertiesByName = propMap
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

    if let additionalProperties {
      if additionalProperties is SchemaNone {
        try container.encode(false, forKey: .additionalProperties)
      } else {
        try container.encode(AnyEncodable(additionalProperties), forKey: .additionalProperties)
      }
    }

    if let patternProperties, !patternProperties.isEmpty {
      var patternContainer = container.nestedContainer(
        keyedBy: DynamicCodingKeys.self,
        forKey: .patternProperties
      )
      for prop in patternProperties {
        try patternContainer.encode(
          AnyEncodable(prop.type),
          forKey: DynamicCodingKeys(stringValue: prop.pattern)
        )
      }
    }
  }

  public func validate(instance: JSONValue) throws -> ValidationOutput {
    guard case .object(let dict) = instance else {
      if omitType {
        return ValidationOutput(instance: instance, children: [:])
      } else {
        throw ValidationError(
          path: "/",
          message: "Expected object, got \(instance.typeName)"
        )
      }
    }

    var children: [String: ValidationOutput] = [:]

    for (key, val) in dict {
      var matchedAnyPattern = false
      var patternOutputs: [ValidationOutput] = []

      // Check pattern properties using precompiled regexes
      if let patternProperties {
        for patProp in patternProperties {
          if let regex = patProp.regex {
            let range = NSRange(key.startIndex..<key.endIndex, in: key)
            if regex.firstMatch(in: key, options: [], range: range) != nil {
              matchedAnyPattern = true
              do {
                let out = try patProp.type.validate(instance: val)
                patternOutputs.append(out)
              } catch let error as ValidationError {
                let segment = key
                let prependedPath =
                  error.path == "/"
                  ? "/\(segment)"
                  : "/\(segment)\(error.path)"
                throw ValidationError(path: prependedPath, message: error.message)
              }
            }
          }
        }
      }

      // Check standard properties in O(1) time
      var standardOutput: ValidationOutput? = nil
      if let property = propertiesByName[key] {
        do {
          standardOutput = try property.type.validate(instance: val)
        } catch let error as ValidationError {
          let segment = key
          let prependedPath =
            error.path == "/"
            ? "/\(segment)"
            : "/\(segment)\(error.path)"
          throw ValidationError(path: prependedPath, message: error.message)
        }
      }

      // Check additional properties
      var additionalOutput: ValidationOutput? = nil
      let isDeclaredProperty = propertyNames.contains(key)
      if !isDeclaredProperty && !matchedAnyPattern {
        if let additionalPropertiesSchema = additionalProperties {
          if additionalPropertiesSchema is SchemaNone {
            throw ValidationError(
              path: "/\(key)",
              message: "additional property '\(key)' is not allowed"
            )
          }
          do {
            additionalOutput = try additionalPropertiesSchema.validate(instance: val)
          } catch let error as ValidationError {
            let segment = key
            let prependedPath =
              error.path == "/"
              ? "/\(segment)"
              : "/\(segment)\(error.path)"
            throw ValidationError(path: prependedPath, message: error.message)
          }
        }
      }

      // Merge all outputs for this key
      var keyOutputs: [ValidationOutput] = []
      if let standardOutput {
        keyOutputs.append(standardOutput)
      }
      keyOutputs.append(contentsOf: patternOutputs)
      if let additionalOutput {
        keyOutputs.append(additionalOutput)
      }

      if !keyOutputs.isEmpty {
        children[key] = mergeValidationOutputs(keyOutputs, instance: val)
      }
    }

    // Check for missing required properties
    for property in properties {
      if property.isRequired && dict[property.name] == nil {
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
    case patternProperties
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
