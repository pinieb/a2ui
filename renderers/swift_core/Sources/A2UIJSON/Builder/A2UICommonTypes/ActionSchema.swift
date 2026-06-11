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
  public static let action = ExternalSchemaStub(
    uri: A2UICommonSchema.uri(for: "ActionSchema"),
    localSchema: SchemaAnyOf([
      SchemaObject(additionalProperties: false) {
        SchemaProperty(
          name: "event",
          type: SchemaObject(additionalProperties: false) {
            SchemaProperty(
              name: "name",
              type: SchemaString(),
              isRequired: true
            )
            SchemaProperty(name: "context", type: SchemaActionContext())
          },
          isRequired: true
        )
      },
      SchemaObject(additionalProperties: false) {
        SchemaProperty(
          name: "functionCall",
          type: SchemaReference(A2UICommonSchema.functionCall),
          isRequired: true
        )
      },
    ])
  )
}

public struct SchemaActionContext: SchemaType {
  public init() {}

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode("object", forKey: .type)

    try container.encode(
      SchemaReference(A2UICommonSchema.dynamicValue),
      forKey: .additionalProperties
    )
  }

  public func validate(instance: JSONValue) throws -> ValidationOutput {
    guard case .object(let dict) = instance else {
      throw ValidationError(
        path: "/",
        message: "Expected object for context, got \(instance.typeName)"
      )
    }

    var validatedChildren: [String: ValidationOutput] = [:]
    for (key, val) in dict {
      do {
        let out = try A2UICommonSchema.dynamicValue.validate(instance: val)
        validatedChildren[key] = out
      } catch let error as ValidationError {
        let prependedPath =
          error.path == "/"
          ? "/\(key)"
          : "/\(key)\(error.path)"
        throw ValidationError(path: prependedPath, message: error.message)
      }
    }

    return ValidationOutput(instance: instance, children: validatedChildren)
  }

  private enum CodingKeys: String, CodingKey {
    case type
    case additionalProperties
  }
}
