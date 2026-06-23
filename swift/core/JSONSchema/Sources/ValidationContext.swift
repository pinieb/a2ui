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

/// Holds the state of the validation process.
public struct ValidationContext: Sendable {
  /// The configuration options for validation.
  public let configuration: ValidatorConfiguration

  /// The schema registry containing referenced schemas.
  public let schemaRegistry: SchemaRegistry

  /// The location in the instance being validated.
  public let instanceLocation: JSONPointer

  /// The current recursion/execution depth.
  public let depth: Int

  /// Initializes a new ValidationContext.
  public init(
    configuration: ValidatorConfiguration = ValidatorConfiguration(),
    schemaRegistry: SchemaRegistry = SchemaRegistry(),
    instanceLocation: JSONPointer = JSONPointer(),
    depth: Int = 0
  ) {
    self.configuration = configuration
    self.schemaRegistry = schemaRegistry
    self.instanceLocation = instanceLocation
    self.depth = depth
  }

  /// Returns a new context for validating a child element (e.g. property or array item).
  /// - Parameter key: The segment to append to the current instance location.
  /// - Returns: A new ValidationContext with incremented depth and updated location.
  /// - Throws: ValidationError.maxDepthExceeded if the depth limit is reached.
  public func passingDown(toInstanceKey key: String) throws -> ValidationContext {
    guard depth < configuration.maxEvaluationDepth else {
      throw ValidationError.maxDepthExceeded
    }
    return ValidationContext(
      configuration: configuration,
      schemaRegistry: schemaRegistry,
      instanceLocation: instanceLocation.appending(segment: key),
      depth: depth + 1
    )
  }

  /// Returns a new context for validating a child element at an array index.
  /// - Parameter index: The index to append to the current instance location.
  /// - Returns: A new ValidationContext with incremented depth and updated location.
  /// - Throws: ValidationError.maxDepthExceeded if the depth limit is reached.
  public func passingDown(toInstanceIndex index: Int) throws -> ValidationContext {
    return try passingDown(toInstanceKey: String(index))
  }

  /// Returns a new context with incremented depth.
  /// - Returns: A new ValidationContext with incremented depth.
  /// - Throws: ValidationError.maxDepthExceeded if the depth limit is reached.
  public func incrementingDepth() throws -> ValidationContext {
    guard depth < configuration.maxEvaluationDepth else {
      throw ValidationError.maxDepthExceeded
    }
    return ValidationContext(
      configuration: configuration,
      schemaRegistry: schemaRegistry,
      instanceLocation: instanceLocation,
      depth: depth + 1
    )
  }
}

