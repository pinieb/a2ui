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

extension A2UICommonSchema {
  public static let functionCall = ExternalSchemaStub(
    uri: A2UICommonSchema.uri(for: "FunctionCallSchema"),
    localSchema: SchemaObject {
      SchemaProperty(name: "call", type: SchemaString(), isRequired: true)
      SchemaProperty(name: "args", type: SchemaFunctionCallArgs())
      SchemaProperty(name: "returnType", type: SchemaString())
    }
  )
}

public struct SchemaFunctionCallArgs: SchemaType {
  public init() {}

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode("object", forKey: .type)

    var addPropsContainer = container.nestedContainer(
      keyedBy: AdditionalPropertiesCodingKeys.self,
      forKey: .additionalProperties
    )

    let subschemas: [any SchemaType] = [
      SchemaReference(A2UICommonSchema.dynamicValue),
      GenericObjectSchema(),
    ]
    try addPropsContainer.encode(
      subschemas.map { AnyEncodable($0) },
      forKey: .anyOf
    )
  }

  public func validate(instance: JSONValue) throws -> ValidationOutput {
    guard case .object(let dict) = instance else {
      throw ValidationError(
        path: "/",
        message: "Expected object for args, got \(instance.typeName)"
      )
    }

    var validatedChildren: [String: ValidationOutput] = [:]
    for (key, val) in dict {
      do {
        let out = try A2UICommonSchema.dynamicValue.validate(instance: val)
        validatedChildren[key] = out
      } catch {
        do {
          let out = try GenericObjectSchema().validate(instance: val)
          validatedChildren[key] = out
        } catch {
          throw ValidationError(
            path: "/\(key)",
            message: "Value does not match DynamicValue or object"
          )
        }
      }
    }

    return ValidationOutput(instance: instance, children: validatedChildren)
  }

  private enum CodingKeys: String, CodingKey {
    case type
    case additionalProperties
  }

  private enum AdditionalPropertiesCodingKeys: String, CodingKey {
    case anyOf
  }
}

struct GenericObjectSchema: SchemaType {
  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode("object", forKey: .type)
  }

  func validate(instance: JSONValue) throws -> ValidationOutput {
    guard case .object = instance else {
      throw ValidationError(
        path: "/",
        message: "Expected object, got \(instance.typeName)"
      )
    }
    return ValidationOutput(instance: instance)
  }

  private enum CodingKeys: String, CodingKey {
    case type
  }
}
