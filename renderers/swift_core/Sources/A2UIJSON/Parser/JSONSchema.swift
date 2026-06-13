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

public struct JSONSchemaParser {
  /// Parses a JSON Schema string directly into the unified `JSONSchema` struct.
  public static func parse(_ schemaString: String) throws -> JSONSchema {
    let data = Data(schemaString.utf8)
    let schema = try JSONDecoder().decode(JSONSchema.self, from: data)
    schema.resolveLexicalScopes()
    return schema
  }
}

// Retain compatibility for `JSONSchema.parse` signature
/// A thread-safe, high-performance registry for dynamically resolved schemas.
public final class DynamicRegistry: @unchecked Sendable {
  private let lock = NSLock()
  private var storage: [URL: JSONSchema] = [:]

  public subscript(url: URL) -> JSONSchema? {
    get {
      lock.lock()
      defer { lock.unlock() }
      return storage[url]
    }
    set {
      lock.lock()
      defer { lock.unlock() }
      newValue?.retrievalURI = url
      storage[url] = newValue
    }
  }

  public func removeAll() {
    lock.lock()
    defer { lock.unlock() }
    storage.removeAll()
  }
}

extension JSONSchema {
  /// The global registry for dynamically resolved schemas.
  /// Fully thread-safe and optimized to avoid dictionary copying under concurrent validation.
  public static let dynamicRegistry = DynamicRegistry()
  public static nonisolated(unsafe) var enableDebugPrinting = false

  public static func parse(_ schemaString: String) throws -> JSONSchema {
    return try JSONSchemaParser.parse(schemaString)
  }
}
