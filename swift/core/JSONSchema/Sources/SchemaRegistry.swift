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

/// A thread-safe registry that acts as a cache for compiled JSON Schema nodes.
///
/// This registry allows for schema composition and reference resolution ($ref)
/// by maintaining a mapping from full schema URIs to their compiled representation.
public final class SchemaRegistry: @unchecked Sendable {
  private let lock = NSLock()
  private var cache: [String: SchemaNode] = [:]

  public init() {}

  /// Registers a compiled schema node under the specified identity.
  /// - Parameters:
  ///   - node: The compiled SchemaNode to cache.
  ///   - identity: The SchemaIdentity containing the full URI for the node.
  public func register(_ node: SchemaNode, for identity: SchemaIdentity) {
    lock.lock()
    defer { lock.unlock() }
    cache[identity.fullURI] = node
  }

  /// Resolves and retrieves a compiled schema node by its full URI string.
  /// - Parameter uri: The full URI string of the schema to retrieve.
  /// - Returns: The cached SchemaNode, or nil if not found.
  public func resolve(uri: String) -> SchemaNode? {
    lock.lock()
    defer { lock.unlock() }
    guard let normalizedIdentity = SchemaIdentity(uri: uri) else {
      return nil
    }
    return cache[normalizedIdentity.fullURI]
  }
}
