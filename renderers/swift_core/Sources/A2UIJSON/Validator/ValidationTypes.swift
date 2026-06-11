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
  public let matchedSchemaIDs: [String]
  public let children: [String: ValidationOutput]

  public init(
    instance: JSONValue,
    matchedSchemaIDs: [String] = [],
    children: [String: ValidationOutput] = [:]
  ) {
    self.instance = instance
    self.matchedSchemaIDs = matchedSchemaIDs
    self.children = children
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
  instance: JSONValue
) -> ValidationOutput {
  var matchedIDs: [String] = []
  var children: [String: ValidationOutput] = [:]

  for output in outputs {
    matchedIDs.append(contentsOf: output.matchedSchemaIDs)
    for (key, val) in output.children {
      if let existing = children[key] {
        children[key] = mergeValidationOutputs(
          [existing, val],
          instance: val.instance
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
    matchedSchemaIDs: uniqueIDs,
    children: children
  )
}
