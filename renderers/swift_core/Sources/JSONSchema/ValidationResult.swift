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

/// Represents the output of a validation step, supporting the hierarchical 2020-12 format.
public struct ValidationResult: Sendable, Equatable {
  /// Whether the instance is valid against the schema.
  public let isValid: Bool

  /// The location of the validated JSON value within the instance.
  public let instanceLocation: JSONPointer

  /// The identity of the schema that performed the validation.
  public let schemaLocation: SchemaIdentity

  /// Any error messages generated during evaluation.
  public let errors: [String]

  /// The annotations collected during validation.
  public let annotations: [String: JSONValue]

  /// Validation results of subschemas/applicators.
  public let childResults: [ValidationResult]

  /// Initializes a ValidationResult.
  public init(
    isValid: Bool,
    instanceLocation: JSONPointer = JSONPointer(),
    schemaLocation: SchemaIdentity = SchemaIdentity(baseURI: ""),
    errors: [String] = [],
    annotations: [String: JSONValue] = [:],
    childResults: [ValidationResult] = []
  ) {
    self.isValid = isValid
    self.instanceLocation = instanceLocation
    self.schemaLocation = schemaLocation
    self.errors = errors
    self.annotations = annotations
    self.childResults = childResults
  }

  /// Creates a successful ValidationResult.
  public static func success(
    annotations: [String: JSONValue] = [:],
    childResults: [ValidationResult] = []
  ) -> ValidationResult {
    return ValidationResult(
      isValid: true,
      annotations: annotations,
      childResults: childResults
    )
  }

  /// Creates a failed ValidationResult with a single error.
  public static func failure(
    error: String,
    childResults: [ValidationResult] = []
  ) -> ValidationResult {
    return ValidationResult(
      isValid: false,
      errors: [error],
      childResults: childResults
    )
  }

  /// Creates a failed ValidationResult with multiple errors.
  public static func failure(
    errors: [String],
    childResults: [ValidationResult] = []
  ) -> ValidationResult {
    return ValidationResult(
      isValid: false,
      errors: errors,
      childResults: childResults
    )
  }

  /// Returns a copy of the validation result with localized paths.
  public func localized(
    instanceLocation: JSONPointer,
    schemaLocation: SchemaIdentity
  ) -> ValidationResult {
    return ValidationResult(
      isValid: isValid,
      instanceLocation: instanceLocation,
      schemaLocation: schemaLocation,
      errors: errors,
      annotations: annotations,
      childResults: childResults
    )
  }
}
