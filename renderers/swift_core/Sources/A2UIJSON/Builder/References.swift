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

public struct ExternalSchemaStub: SchemaType {
  public let uri: String
  private let localSchema: SchemaType?

  public init(uri: String, localSchema: SchemaType? = nil) {
    self.uri = uri
    self.localSchema = localSchema
  }

  public init(
    uri: String,
    @SchemaBuilder _ builder: () -> [SchemaProperty]
  ) {
    self.uri = uri
    self.localSchema = SchemaObject(builder)
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(uri, forKey: .id)
    if let localSchema {
      try localSchema.encode(to: encoder)
    }
  }

  public func validate(instance: JSONValue) throws -> ValidationOutput {
    if let localSchema {
      do {
        let innerOutput = try localSchema.validate(instance: instance)
        let mergedIDs = (innerOutput.matchedSchemaIDs + [uri])
          .reduce(into: [String]()) {
            if !$0.contains($1) { $0.append($1) }
          }
        return ValidationOutput(
          instance: instance,
          matchedSchemaIDs: mergedIDs,
          children: innerOutput.children
        )
      } catch let error as ValidationError {
        throw ValidationError(
          path: error.path,
          message: "[\(uri)] \(error.message)"
        )
      }
    }

    return ValidationOutput(
      instance: instance,
      matchedSchemaIDs: [uri]
    )
  }

  private enum CodingKeys: String, CodingKey {
    case id = "$id"
  }
}

public struct SchemaReference: SchemaType {
  public let stub: ExternalSchemaStub

  public init(_ stub: ExternalSchemaStub) {
    self.stub = stub
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)

    let tracker = encoder.userInfo[.referenceTracker] as? ReferenceTracker
    if let tracker, tracker.bundleExternalRefs {
      let key = tracker.register(stub)
      try container.encode("#/$defs/\(key)", forKey: .ref)
    } else {
      try container.encode(stub.uri, forKey: .ref)
    }
  }

  public func validate(instance: JSONValue) throws -> ValidationOutput {
    return try stub.validate(instance: instance)
  }

  private enum CodingKeys: String, CodingKey {
    case ref = "$ref"
  }
}
