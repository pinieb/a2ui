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

public struct JSONSchema {
  public static func parse(_ schemaString: String) throws -> SchemaType {
    let data = Data(schemaString.utf8)
    let rawSchema = try JSONDecoder().decode(RawSchema.self, from: data)
    return try mapToSchemaType(rawSchema)
  }
}

// MARK: - Private Parser Models

private final class RawSchema: Decodable {
  var type: String? = nil
  var properties: [String: RawSchema]? = nil
  var required: [String]? = nil
  var anyOf: [RawSchema]? = nil
  var allOf: [RawSchema]? = nil
  var ref: String? = nil
  var id: String? = nil
  var items: RawSchema? = nil

  private enum CodingKeys: String, CodingKey {
    case type
    case properties
    case required
    case anyOf
    case allOf
    case ref = "$ref"
    case id = "$id"
    case items
  }
}

private func mapToSchemaType(_ raw: RawSchema) throws -> SchemaType {
  if let ref = raw.ref {
    return SchemaReference(ExternalSchemaStub(uri: ref))
  }

  if let anyOf = raw.anyOf {
    let subschemas = try anyOf.map { try mapToSchemaType($0) }
    return SchemaAnyOf(subschemas)
  }

  if let allOf = raw.allOf {
    let subschemas = try allOf.map { try mapToSchemaType($0) }
    return SchemaAllOf(subschemas)
  }

  guard let type = raw.type else {
    throw DecodingError.dataCorrupted(
      DecodingError.Context(
        codingPath: [],
        debugDescription: "Schema must have a type, $ref, anyOf, or allOf"
      )
    )
  }

  switch type {
  case "string":
    return SchemaString()
  case "integer":
    return SchemaInteger()
  case "boolean":
    return SchemaBoolean()
  case "number":
    return SchemaNumber()
  case "array":
    guard let rawItems = raw.items else {
      throw DecodingError.dataCorrupted(
        DecodingError.Context(
          codingPath: [],
          debugDescription: "Array schema is missing 'items' property"
        )
      )
    }
    let itemsSchema = try mapToSchemaType(rawItems)
    return SchemaArray(items: itemsSchema)
  case "object":
    var properties: [SchemaProperty] = []
    let requiredSet = Set(raw.required ?? [])
    if let rawProps = raw.properties {
      for (name, rawProp) in rawProps {
        let propType = try mapToSchemaType(rawProp)
        let isRequired = requiredSet.contains(name)
        properties.append(
          SchemaProperty(name: name, type: propType, isRequired: isRequired)
        )
      }
    }
    return SchemaObject(properties: properties)
  default:
    throw DecodingError.dataCorrupted(
      DecodingError.Context(
        codingPath: [],
        debugDescription: "Unsupported schema type: \(type)"
      )
    )
  }
}
