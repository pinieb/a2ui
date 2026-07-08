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

import OrderedJSON

/// Top-level envelope for client-to-server messages (actions or errors).
public enum ClientToServerMessage: Equatable, Codable, Sendable {
  case action(ResolvedAction)
  case error(ClientServerError)

  private enum CodingKeys: String, CodingKey {
    case version
    case action
    case error
  }

  private enum ActionCodingKeys: String, CodingKey {
    case event
    case context
    case call
    case args
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let version = try container.decode(String.self, forKey: .version)
    guard version == "v0.9" || version == "v0.9.1" else {
      throw DecodingError.dataCorruptedError(
        forKey: .version,
        in: container,
        debugDescription: "Unsupported version: \(version)"
      )
    }

    if container.contains(.action) {
      let actionContainer = try container.nestedContainer(
        keyedBy: ActionCodingKeys.self,
        forKey: .action
      )
      let identity: ResolvedAction.Identity
      if let eventName = try actionContainer.decodeIfPresent(String.self, forKey: .event) {
        let context = try actionContainer.decodeIfPresent(
          [String: JSONValue].self,
          forKey: .context
        )
        identity = .event(name: eventName, context: context)
      } else if let callName = try actionContainer.decodeIfPresent(String.self, forKey: .call) {
        let args = try actionContainer.decodeIfPresent(
          [String: JSONValue].self,
          forKey: .args
        )
        identity = .function(call: callName, args: args)
      } else {
        throw DecodingError.dataCorrupted(
          DecodingError.Context(
            codingPath: decoder.codingPath,
            debugDescription: "Action must contain either 'event' or 'call'"
          )
        )
      }
      let actionValue = ResolvedAction(identity: identity, trigger: {})
      self = .action(actionValue)
    } else if let errorValue = try container.decodeIfPresent(
      ClientServerError.self,
      forKey: .error
    ) {
      self = .error(errorValue)
    } else {
      throw DecodingError.dataCorrupted(
        DecodingError.Context(
          codingPath: decoder.codingPath,
          debugDescription: "Message must contain either 'action' or 'error'"
        )
      )
    }
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode("v0.9.1", forKey: .version)

    switch self {
    case .action(let action):
      var actionContainer = container.nestedContainer(
        keyedBy: ActionCodingKeys.self,
        forKey: .action
      )
      switch action.identity {
      case .event(let name, let context):
        try actionContainer.encode(name, forKey: .event)
        if let context {
          try actionContainer.encode(context, forKey: .context)
        }
      case .function(let call, let args):
        try actionContainer.encode(call, forKey: .call)
        if let args {
          try actionContainer.encode(args, forKey: .args)
        }
      }
    case .error(let error):
      try container.encode(error, forKey: .error)
    }
  }
}
