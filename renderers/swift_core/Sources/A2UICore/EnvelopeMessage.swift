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

/// A container message enclosing one of the supported incoming server-to-client commands.
public enum EnvelopeMessage: Codable, Sendable, Equatable {
  case createSurface(CreateSurfaceMessage)
  case updateComponents(UpdateComponentsMessage)
  case updateDataModel(UpdateDataModelMessage)
  case deleteSurface(DeleteSurfaceMessage)

  private enum CodingKeys: String, CodingKey {
    case createSurface
    case updateComponents
    case updateDataModel
    case deleteSurface
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    if let createSurface = try container.decodeIfPresent(
      CreateSurfaceMessage.self,
      forKey: .createSurface
    ) {
      self = .createSurface(createSurface)
    } else if let updateComponents = try container.decodeIfPresent(
      UpdateComponentsMessage.self,
      forKey: .updateComponents
    ) {
      self = .updateComponents(updateComponents)
    } else if let updateDataModel = try container.decodeIfPresent(
      UpdateDataModelMessage.self,
      forKey: .updateDataModel
    ) {
      self = .updateDataModel(updateDataModel)
    } else if let deleteSurface = try container.decodeIfPresent(
      DeleteSurfaceMessage.self,
      forKey: .deleteSurface
    ) {
      self = .deleteSurface(deleteSurface)
    } else {
      let context = DecodingError.Context(
        codingPath: container.codingPath,
        debugDescription: """
          EnvelopeMessage must contain one of: 'createSurface', 'updateComponents', \
          'updateDataModel', or 'deleteSurface'
          """
      )
      throw DecodingError.dataCorrupted(context)
    }
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    switch self {
    case .createSurface(let message):
      try container.encode(message, forKey: .createSurface)
    case .updateComponents(let message):
      try container.encode(message, forKey: .updateComponents)
    case .updateDataModel(let message):
      try container.encode(message, forKey: .updateDataModel)
    case .deleteSurface(let message):
      try container.encode(message, forKey: .deleteSurface)
    }
  }
}
