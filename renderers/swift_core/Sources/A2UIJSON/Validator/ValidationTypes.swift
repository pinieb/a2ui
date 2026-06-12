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

public struct ValidationOutput: Sendable, Equatable {
  public let instance: JSONValue
  public let schema: JSONSchema
  public let matchedSchemaIDs: [String]
  public let children: [String: ValidationOutput]
  public let evaluatedProperties: Set<String>
  public let evaluatedItems: Set<Int>

  public init(
    instance: JSONValue,
    schema: JSONSchema = JSONSchema(booleanSchema: true),
    matchedSchemaIDs: [String] = [],
    children: [String: ValidationOutput] = [:],
    evaluatedProperties: Set<String> = [],
    evaluatedItems: Set<Int> = []
  ) {
    self.instance = instance
    self.schema = schema
    self.matchedSchemaIDs = matchedSchemaIDs
    self.children = children
    self.evaluatedProperties = evaluatedProperties
    self.evaluatedItems = evaluatedItems
  }
}

public struct ValidationError: Error, Sendable, Equatable {
  public let path: String
  public let message: String

  public init(path: String, message: String) {
    self.path = path
    self.message = message
  }
}

// MARK: - Internal Helpers

func mergeValidationOutputs(
  _ outputs: [ValidationOutput],
  instance: JSONValue,
  schema: JSONSchema
) -> ValidationOutput {
  var matchedIDs: [String] = []
  var children: [String: ValidationOutput] = [:]
  var evalProps: Set<String> = []
  var evalItems: Set<Int> = []

  for output in outputs {
    matchedIDs.append(contentsOf: output.matchedSchemaIDs)
    evalProps.formUnion(output.evaluatedProperties)
    evalItems.formUnion(output.evaluatedItems)
    for (key, val) in output.children {
      if let existing = children[key] {
        children[key] = mergeValidationOutputs(
          [existing, val],
          instance: val.instance,
          schema: val.schema
        )
      } else {
        children[key] = val
      }
    }
  }

  var seen = Set<String>()
  let uniqueIDs = matchedIDs.filter { seen.insert($0).inserted }

  return ValidationOutput(
    instance: instance,
    schema: schema,
    matchedSchemaIDs: uniqueIDs,
    children: children,
    evaluatedProperties: evalProps,
    evaluatedItems: evalItems
  )
}
