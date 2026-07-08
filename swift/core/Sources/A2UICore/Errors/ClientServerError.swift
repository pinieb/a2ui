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

/// Encapsulates all client-to-server error types.
public enum ClientServerError: Equatable, Codable, Sendable {
  case validationFailed(ValidationFailedError)
  case generic(GenericError)

  public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    if let validation = try? container.decode(ValidationFailedError.self) {
      self = .validationFailed(validation)
    } else if let generic = try? container.decode(GenericError.self) {
      self = .generic(generic)
    } else {
      throw DecodingError.dataCorrupted(
        DecodingError.Context(
          codingPath: decoder.codingPath,
          debugDescription: "Unknown ClientServerError structure"
        )
      )
    }
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    switch self {
    case .validationFailed(let validation):
      try container.encode(validation)
    case .generic(let generic):
      try container.encode(generic)
    }
  }
}
