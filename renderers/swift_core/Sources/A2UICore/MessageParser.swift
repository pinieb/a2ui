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

/// A thread-safe parser for decoding A2UI server-to-client messages.
public final class MessageParser: Sendable {
  private let decoder: JSONDecoder

  public init(decoder: JSONDecoder = JSONDecoder()) {
    self.decoder = decoder
  }

  /// Parses an `EnvelopeMessage` from a JSON-encoded string.
  public func parse(jsonString: String) throws -> EnvelopeMessage {
    let data = Data(jsonString.utf8)
    return try decode(jsonData: data)
  }

  /// Decodes an `EnvelopeMessage` from raw JSON data.
  public func decode(jsonData: Data) throws -> EnvelopeMessage {
    try decoder.decode(EnvelopeMessage.self, from: jsonData)
  }
}
