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

public struct SchemaAnyOf: SchemaType {
  public let subschemas: [SchemaType]

  public init(_ subschemas: [SchemaType]) {
    self.subschemas = subschemas
  }

  public init(subschemas: [SchemaType]) {
    self.subschemas = subschemas
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(
      subschemas.map { AnyEncodable($0) },
      forKey: .anyOf
    )
  }

  public func validate(instance: JSONValue) throws -> ValidationOutput {
    var matchedOutputs: [ValidationOutput] = []
    var errors: [ValidationError] = []
    for subschema in subschemas {
      do {
        let output = try subschema.validate(instance: instance)
        matchedOutputs.append(output)
      } catch let error as ValidationError {
        errors.append(error)
      } catch {
        errors.append(
          ValidationError(path: "/", message: String(describing: error))
        )
      }
    }
    guard !matchedOutputs.isEmpty else {
      let depst = errors.map { ($0, $0.path.split(separator: "/").count) }
      if let maxDepth = depst.map({ $1 }).max() {
        let deepestErrors = depst.filter { $1 == maxDepth }.map { $0.0 }
        if deepestErrors.count == 1 {
          throw deepestErrors[0]
        } else {
          let combinedMessage =
            "Instance did not match any subschema in anyOf: ["
            + deepestErrors.map { $0.message }.joined(separator: ", ")
            + "]"
          throw ValidationError(
            path: deepestErrors[0].path,
            message: combinedMessage
          )
        }
      }
      throw ValidationError(
        path: "/",
        message: "Instance did not match any subschema in anyOf"
      )
    }
    return mergeValidationOutputs(matchedOutputs, instance: instance)
  }

  private enum CodingKeys: String, CodingKey {
    case anyOf
  }
}

public struct SchemaAllOf: SchemaType {
  public let subschemas: [SchemaType]

  public init(_ subschemas: [SchemaType]) {
    self.subschemas = subschemas
  }

  public init(subschemas: [SchemaType]) {
    self.subschemas = subschemas
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(
      subschemas.map { AnyEncodable($0) },
      forKey: .allOf
    )
  }

  public func validate(instance: JSONValue) throws -> ValidationOutput {
    var matchedOutputs: [ValidationOutput] = []
    for subschema in subschemas {
      let output = try subschema.validate(instance: instance)
      matchedOutputs.append(output)
    }
    return mergeValidationOutputs(matchedOutputs, instance: instance)
  }

  private enum CodingKeys: String, CodingKey {
    case allOf
  }
}
