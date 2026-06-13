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

/// A lightweight indirection wrapper for recursive struct properties.
public final class Box<Val: Codable & Equatable & Sendable>: Codable, Equatable, Sendable {
  public let value: Val
  public init(_ value: Val) {
    self.value = value
  }
  public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    self.value = try container.decode(Val.self)
  }
  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(value)
  }
  public static func == (lhs: Box<Val>, rhs: Box<Val>) -> Bool {
    lhs.value == rhs.value
  }
}
